import Foundation
import SwiftData

@main struct AccessPolicyChecks {
    @MainActor static func main() throws {
        let schema = Schema([CompanyProfile.self, Customer.self, JobRecord.self, JobPhoto.self, WorkEntry.self, MaterialEntry.self, PurchaseItem.self, ProjectTrade.self, ProjectParty.self, WorkPackage.self, Supplier.self, ProductCatalogItem.self, InvoiceRecord.self, CreditNoteRecord.self, AppMetadata.self])
        func makeContext() throws -> ModelContext {
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            return ModelContext(container)
        }
        let context = try makeContext()
        let customer = Customer(name: "Access fixture customer", address: "Fixture road 1")
        context.insert(customer)
        let first = JobRecord(jobNumber: "ACCESS-1", title: "First existing job", customer: customer, status: .inProgress)
        let second = JobRecord(jobNumber: "ACCESS-2", title: "Second existing job", customer: customer)
        let closed = JobRecord(jobNumber: "ACCESS-3", title: "Completed history", customer: customer, status: .completed)
        let archived = JobRecord(jobNumber: "ACCESS-4", title: "Archived history", customer: customer, archivedAt: .now)
        let jobs = [first, second, closed, archived]
        for job in jobs { context.insert(job) }
        let work = WorkEntry(workDate: .now, details: "Original work", durationMinutes: 125, job: second)
        context.insert(work); second.workEntries.append(work)
        let material = MaterialEntry(name: "Original material", quantity: 3, unit: "kg", job: first, unitPrice: 120)
        context.insert(material); first.materialEntries.append(material)
        let company = CompanyProfile(name: "Fixture company", organizationNumber: "974761076", address: "Fixture road 2", bankAccount: "1234.45.68454")
        context.insert(company)
        let snapshotBytes = try JSONEncoder().encode(SalesDocumentService.snapshot(job: first, company: company))
        let invoice = InvoiceRecord(invoiceNumber: "ACCESS-INV-1", jobID: first.id, jobNumber: first.jobNumber, issuedAt: .now, dueDate: .now, snapshotData: snapshotBytes)
        context.insert(invoice)
        let root = FileManager.default.temporaryDirectory.appending(path: "JobbBevis-Access-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let relativePath = "Photos/\(second.id.uuidString)/fixture.jpg"
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appending(path: "JobbBevis")
        let file = support.appending(path: relativePath)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let imageBytes = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        try imageBytes.write(to: file)
        let photo = JobPhoto(relativePath: relativePath, category: .during, caption: "Original caption", sortOrder: 0, job: second)
        context.insert(photo); second.photos.append(photo)
        try context.save()
        let dates = jobs.map(\.updatedAt)
        let statuses = jobs.map(\.statusRawValue)
        let free = JobAccessPolicy(tier: .free, selectedJobID: nil)
        assert(!free.canCreateJob(in: jobs))
        assert(free.editableJobID(in: jobs) == nil) // Never choose or complete a legacy job silently.
        assert(!free.canReopen(closed, in: jobs))
        let selected = JobAccessPolicy(tier: .free, selectedJobID: second.id)
        assert(selected.canEdit(second, in: jobs))
        assert(!selected.canEdit(first, in: jobs))
        assert(!selected.canEdit(closed, in: jobs) && !selected.canEdit(archived, in: jobs))
        assert(selected.canSave(second, status: .completed, in: jobs))
        assert(!selected.canSave(first, status: .inProgress, in: jobs))
        assert(!selected.canSave(nil, status: .planned, in: jobs))
        assert(jobs.map(\.updatedAt) == dates && jobs.map(\.statusRawValue) == statuses)
        let plus = JobAccessPolicy(tier: .plus, selectedJobID: second.id)
        assert(plus.canCreateJob(in: jobs) && plus.canReopen(closed, in: jobs))
        assert(jobs.allSatisfy { plus.canEdit($0, in: jobs) })
        // Downgrade reuses the same selected job; all other objects remain intact.
        assert(selected.editableJobID(in: jobs) == second.id)
        let jobCount = try context.fetchCount(FetchDescriptor<JobRecord>())
        assert(jobCount == 4)
        assert(second.workEntries[0].durationMinutes == 125 && first.materialEntries[0].quantity == 3)
        assert(invoice.snapshotData == snapshotBytes)
        // Free can back up and restore every job, including more than one active job and all photos.
        let source = BackupService(applicationDirectoryOverride: root)
        let backup = try source.exportData(from: context)
        let restoredRoot = root.appending(path: "Restored")
        let service = BackupService(applicationDirectoryOverride: restoredRoot)
        let destination = try makeContext()
        let prepared = try service.prepareImport(data: backup)
        try service.restore(prepared, into: destination)
        let restored = try destination.fetch(FetchDescriptor<JobRecord>())
        assert(Set(restored.map(\.id)) == Set(jobs.map(\.id)))
        assert(free.activeJobs(in: restored).count == 2)
        assert(restored.first { $0.id == second.id }!.photos[0].caption == "Original caption")
        let restoredPhoto = restored.first { $0.id == second.id }!.photos[0]
        let restoredImage = try Data(contentsOf: restoredRoot.appending(path: restoredPhoto.relativePath))
        assert(restoredImage == imageBytes)
        let restoredInvoice = try destination.fetch(FetchDescriptor<InvoiceRecord>())[0]
        assert(restoredInvoice.snapshotData == snapshotBytes)
        // Closing frees the slot; reopening is allowed only when it does not create a second active job.
        first.status = .completed
        assert(!free.canCreateJob(in: jobs) && free.editableJobID(in: jobs) == second.id)
        second.status = .completed
        assert(free.canCreateJob(in: jobs) && free.canReopen(closed, in: jobs))
        closed.status = .inProgress
        assert(free.canEdit(closed, in: jobs) && !free.canReopen(archived, in: jobs))
        assert(!free.canSave(second, status: .inProgress, in: jobs))
        assert(free.canCreateJob(in: []))
        // A copied backup does not grant Plus. Only a local free selection is persisted.
        let suite = "JobbBevis-Access-Test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let access = AccessStore(defaults: defaults)
        access.selectedJobID = second.id
        let reloaded = AccessStore(defaults: defaults)
        assert(reloaded.selectedJobID == second.id && !reloaded.hasPlus)
        print("PASS: Free/Plus, multiple legacy jobs, upgrade/downgrade, completion/reopen, immutable history and full photo/data backup restore")
    }
}
