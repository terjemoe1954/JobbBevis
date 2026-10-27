import Foundation
import SwiftData

enum PersistenceService {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CompanyProfile.self,
            Customer.self,
            JobRecord.self,
            JobPhoto.self,
            WorkEntry.self,
            MaterialEntry.self,
            PurchaseItem.self,
            Supplier.self,
            ProductCatalogItem.self,
            InvoiceRecord.self,
            CreditNoteRecord.self,
            AppMetadata.self
        ])
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = supportURL.appending(path: "JobbBevis", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )
        let storeURL = appDirectory.appending(path: "JobbBevis.store")
        let configuration = ModelConfiguration(
            "JobbBevis",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
