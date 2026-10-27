import Foundation
import SwiftData

@MainActor
enum DataMigrationService {
    static func migrateLegacyCatalogData(in context: ModelContext) throws {
        let customers = try context.fetch(FetchDescriptor<Customer>())
        for customer in customers where customer.customerNumber?.isEmpty != false {
            customer.customerNumber = try BusinessNumberService.nextCustomerNumber(in: context)
        }

        let products = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        var suppliersByName: [String: Supplier] = [:]
        for supplier in try context.fetch(FetchDescriptor<Supplier>()) {
            let key = supplier.name.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            suppliersByName[key] = suppliersByName[key] ?? supplier
        }

        for product in products {
            if product.itemNumber?.isEmpty != false {
                product.itemNumber = try BusinessNumberService.nextItemNumber(in: context)
            }
            guard product.supplierRecord == nil else { continue }
            let name = product.supplier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let supplier: Supplier
            if let existing = suppliersByName[key] {
                supplier = existing
            } else {
                supplier = Supplier(
                    supplierNumber: try BusinessNumberService.nextSupplierNumber(in: context),
                    name: name
                )
                context.insert(supplier)
                suppliersByName[key] = supplier
            }
            product.supplierRecord = supplier
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
