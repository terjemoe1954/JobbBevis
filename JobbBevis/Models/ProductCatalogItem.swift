import Foundation
import SwiftData

@Model
final class ProductCatalogItem {
    @Attribute(.unique) var id: UUID
    var itemNumber: String?
    var supplier: String
    var supplierRecord: Supplier?
    var name: String
    var unit: String
    var unitPrice: Decimal
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        itemNumber: String? = nil,
        supplier: String,
        supplierRecord: Supplier? = nil,
        name: String,
        unit: String,
        unitPrice: Decimal,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.itemNumber = itemNumber
        self.supplier = supplier
        self.supplierRecord = supplierRecord
        self.name = name
        self.unit = unit
        self.unitPrice = unitPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
