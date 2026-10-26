import Foundation
import SwiftData

@Model
final class ProductCatalogItem {
    @Attribute(.unique) var id: UUID
    var supplier: String
    var name: String
    var unit: String
    var unitPrice: Decimal
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        supplier: String,
        name: String,
        unit: String,
        unitPrice: Decimal,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.supplier = supplier
        self.name = name
        self.unit = unit
        self.unitPrice = unitPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
