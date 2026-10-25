#if DEBUG
import Foundation
import SwiftData

@MainActor
public enum CoreTestSupport {
    public static func formattedDuration(totalMinutes: Int) -> String {
        EntryFormatting.duration(totalMinutes: totalMinutes)
    }

    public static func nextJobNumbers() throws -> [String] {
        let context = try makeContext()
        return [
            try JobNumberService.nextNumber(in: context),
            try JobNumberService.nextNumber(in: context)
        ]
    }

    public static func relationshipsPersist() throws -> Bool {
        let context = try makeContext()
        let customer = Customer(name: "Test customer")
        let job = JobRecord(jobNumber: "TEST-1", title: "Test job", customer: customer)
        job.workEntries.append(
            WorkEntry(workDate: .now, details: "Work", durationMinutes: 75, job: job)
        )
        job.materialEntries.append(
            MaterialEntry(name: "Board", quantity: 2, unit: "pcs", job: job)
        )
        context.insert(customer)
        context.insert(job)
        try context.save()

        guard let stored = try context.fetch(FetchDescriptor<JobRecord>()).first else {
            return false
        }
        return stored.customer.name == "Test customer"
            && stored.workEntries.first?.durationMinutes == 75
            && stored.materialEntries.first?.quantity == 2
    }

    public static func backupRoundTripPreservesData() throws -> Bool {
        let source = try makeContext()
        let customer = Customer(name: "Example", isSampleData: true)
        let job = JobRecord(
            jobNumber: "DEMO-1",
            title: "Example job",
            customer: customer,
            isSampleData: true
        )
        source.insert(customer)
        source.insert(job)
        try source.save()

        let service = BackupService()
        let prepared = try service.prepareImport(data: service.exportData(from: source))
        let destination = try makeContext()
        try service.restore(prepared, into: destination)

        guard let restored = try destination.fetch(FetchDescriptor<JobRecord>()).first else {
            return false
        }
        return prepared.summary.customers == 1
            && prepared.summary.jobs == 1
            && restored.customer.name == "Example"
            && restored.isSampleData
            && restored.customer.isSampleData
    }

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([
            CompanyProfile.self,
            Customer.self,
            JobRecord.self,
            JobPhoto.self,
            WorkEntry.self,
            MaterialEntry.self,
            AppMetadata.self
        ])
        let configuration = ModelConfiguration(
            "JobbBevisTests-\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }
}
#endif
