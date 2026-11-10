import Foundation
import SwiftData

struct RegisterImportChecks {
    @MainActor static func run() throws {
        let schema = Schema([CompanyProfile.self, Customer.self, JobRecord.self, JobPhoto.self,
            WorkEntry.self, MaterialEntry.self, PurchaseItem.self, ProjectTrade.self,
            ProjectParty.self, WorkPackage.self, Supplier.self, ProductCatalogItem.self,
            InvoiceRecord.self, CreditNoteRecord.self, AppMetadata.self])
        func context() throws -> ModelContext {
            ModelContext(try ModelContainer(for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        }
        func expect(_ value: Bool) { assert(value) }
        let source = try context()
        let customer = Customer(name: "Imported customer", address: "Testveien 2")
        let supplier = Supplier(supplierNumber: "L-1", name: "Imported supplier")
        source.insert(customer); source.insert(supplier)
        source.insert(ProductCatalogItem(itemNumber: "V-1", supplier: supplier.name,
            supplierRecord: supplier, name: "Filler", quantity: 10, unit: "kg", unitPrice: 65))
        let job = JobRecord(jobNumber: "JB-99", title: "Not imported", customer: customer, hourlyRate: 800)
        source.insert(job)
        let work = WorkEntry(workDate: .now, details: "Not imported", durationMinutes: 60, job: job)
        source.insert(work); job.workEntries.append(work)
        source.insert(CompanyProfile(name: "Not imported", organizationNumber: "974761076", address: "Testveien 1"))
        source.insert(AppMetadata(nextJobSequence: 100, nextInvoiceSequence: 900))
        try source.save()
        let snapshot = try SalesDocumentService.snapshot(job: job, company: source.fetch(FetchDescriptor<CompanyProfile>())[0])
        let frozen = try JSONEncoder().encode(snapshot)
        source.insert(InvoiceRecord(invoiceNumber: "2026-00899", jobID: job.id, jobNumber: job.jobNumber,
            issuedAt: .now, dueDate: .now, snapshotData: frozen))
        try source.save()
        let root = FileManager.default.temporaryDirectory.appending(path: "RegisterImport-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = BackupService(applicationDirectoryOverride: root)
        let prepared = try service.prepareImport(data: service.exportData(from: source))
        assert(prepared.summary.customers == 1 && prepared.summary.suppliers == 1 && prepared.summary.products == 1)
        let destination = try context()
        let oldCustomer = Customer(name: "Old customer")
        destination.insert(oldCustomer)
        destination.insert(JobRecord(jobNumber: "JB-7", title: "Remove", customer: oldCustomer))
        destination.insert(CompanyProfile(name: "Keep local company"))
        destination.insert(AppMetadata(nextJobSequence: 8, nextInvoiceSequence: 50))
        destination.insert(Supplier(supplierNumber: "OLD", name: "Remove"))
        let historical = InvoiceRecord(invoiceNumber: "2026-00049", jobID: UUID(), jobNumber: "HISTORY",
            issuedAt: .now, dueDate: .now, snapshotData: frozen)
        destination.insert(historical)
        destination.insert(CreditNoteRecord(creditNoteNumber: "KN-2026-00001", originalInvoiceID: historical.id,
            originalInvoiceNumber: historical.invoiceNumber, jobNumber: historical.jobNumber,
            issuedAt: .now, snapshotData: frozen))
        try destination.save()
        try service.restore(prepared, mode: .registers, into: destination)
        expect(try destination.fetch(FetchDescriptor<JobRecord>()).isEmpty)
        expect(try destination.fetch(FetchDescriptor<WorkEntry>()).isEmpty)
        expect(try destination.fetch(FetchDescriptor<Customer>()).map(\.name) == ["Imported customer"])
        let products = try destination.fetch(FetchDescriptor<ProductCatalogItem>())
        assert(products.count == 1 && products[0].itemNumber == "V-1" && products[0].unitPrice == 65)
        assert(products[0].supplierRecord?.supplierNumber == "L-1")
        expect(try destination.fetch(FetchDescriptor<CompanyProfile>())[0].name == "Keep local company")
        let metadata = try destination.fetch(FetchDescriptor<AppMetadata>())[0]
        assert(metadata.nextJobSequence == 8 && metadata.nextInvoiceSequence == 50)
        let retained = try destination.fetch(FetchDescriptor<InvoiceRecord>())
        assert(retained.count == 1 && retained[0].id == historical.id && retained[0].snapshotData == frozen)
        expect(try destination.fetch(FetchDescriptor<CreditNoteRecord>()).count == 1)
        // Repeating replacement must not duplicate register entries.
        try service.restore(prepared, mode: .registers, into: destination)
        expect(try destination.fetch(FetchDescriptor<ProductCatalogItem>()).count == 1)
        let empty = try context()
        let emptyBackup = try service.prepareImport(data: service.exportData(from: empty))
        try service.restore(emptyBackup, mode: .registers, into: destination)
        expect(try destination.fetch(FetchDescriptor<Customer>()).isEmpty)
        expect(try destination.fetch(FetchDescriptor<Supplier>()).isEmpty)
        expect(try destination.fetch(FetchDescriptor<ProductCatalogItem>()).isEmpty)
        expect(try destination.fetch(FetchDescriptor<InvoiceRecord>()).count == 1)
        // Full restore remains available and restores source work and company.
        try service.restore(prepared, into: destination)
        expect(try destination.fetch(FetchDescriptor<JobRecord>()).count == 1)
        expect(try destination.fetch(FetchDescriptor<WorkEntry>()).count == 1)
        expect(try destination.fetch(FetchDescriptor<CompanyProfile>())[0].name == "Not imported")
        // Broken files are rejected before replacement.
        let unchanged = try service.exportData(from: destination)
        do { _ = try service.prepareImport(data: Data("invalid".utf8)); assertionFailure("Accepted invalid file") }
        catch { }
        expect(try destination.fetch(FetchDescriptor<JobRecord>()).count == 1)
        _ = unchanged
        print("PASS: register-only replacement, linked supplier/product, repeat import, local company/counters, full restore and invalid input")
    }
}
