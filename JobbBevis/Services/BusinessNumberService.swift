import Foundation
import SwiftData

@MainActor
enum BusinessNumberService {
    static func nextCustomerNumber(in context: ModelContext) throws -> String {
        let values = try context.fetch(FetchDescriptor<Customer>()).compactMap(\.customerNumber)
        return nextNumber(prefix: "K", existing: values)
    }

    static func nextItemNumber(in context: ModelContext) throws -> String {
        let values = try context.fetch(FetchDescriptor<ProductCatalogItem>()).compactMap(\.itemNumber)
        return nextNumber(prefix: "V", existing: values)
    }

    static func nextSupplierNumber(in context: ModelContext) throws -> String {
        let values = try context.fetch(FetchDescriptor<Supplier>()).map(\.supplierNumber)
        return nextNumber(prefix: "L", existing: values)
    }

    static func isCustomerNumberAvailable(_ value: String, excluding id: UUID?, in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<Customer>()).allSatisfy {
            $0.id == id || $0.customerNumber?.localizedCaseInsensitiveCompare(value) != .orderedSame
        }
    }

    static func isItemNumberAvailable(_ value: String, excluding id: UUID?, in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<ProductCatalogItem>()).allSatisfy {
            $0.id == id || $0.itemNumber?.localizedCaseInsensitiveCompare(value) != .orderedSame
        }
    }

    static func isSupplierNumberAvailable(_ value: String, excluding id: UUID?, in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<Supplier>()).allSatisfy {
            $0.id == id || $0.supplierNumber.localizedCaseInsensitiveCompare(value) != .orderedSame
        }
    }

    private static func nextNumber(prefix: String, existing: [String]) -> String {
        let highest = existing.compactMap { value in
            value.split(separator: "-").last.flatMap { Int($0) }
        }.max() ?? 0
        return "\(prefix)-\(String(format: "%04d", highest + 1))"
    }
}
