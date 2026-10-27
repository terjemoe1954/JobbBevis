import Foundation
import SwiftData

@MainActor
enum DataResetService {
    static func deleteAll(in context: ModelContext) throws {
        try context.transaction {
            for value in try context.fetch(FetchDescriptor<JobPhoto>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<WorkEntry>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<MaterialEntry>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<PurchaseItem>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<JobRecord>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<Customer>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<ProductCatalogItem>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<Supplier>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<InvoiceRecord>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<CreditNoteRecord>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<CompanyProfile>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<AppMetadata>()) { context.delete(value) }
        }

        let manager = FileManager.default
        let supportURL = try manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = supportURL.appending(path: "JobbBevis", directoryHint: .isDirectory)
        for directoryName in ["Photos", "Logos"] {
            let directory = appDirectory.appending(path: directoryName, directoryHint: .isDirectory)
            if manager.fileExists(atPath: directory.path()) {
                try manager.removeItem(at: directory)
            }
        }

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
    }
}
