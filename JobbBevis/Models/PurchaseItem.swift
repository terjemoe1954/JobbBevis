import Foundation
import SwiftData

@Model
final class PurchaseItem {
    @Attribute(.unique) var id: UUID
    var supplier: String
    var itemName: String
    var quantity: Decimal
    var unit: String
    var unitPrice: Decimal
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var transferredMaterialID: UUID?
    var transferredAt: Date?
    var job: JobRecord

    var isTransferredToMaterials: Bool { transferredMaterialID != nil }

    var lineTotal: Decimal {
        quantity * unitPrice
    }

    init(
        id: UUID = UUID(),
        supplier: String,
        itemName: String,
        quantity: Decimal,
        unit: String,
        unitPrice: Decimal,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        transferredMaterialID: UUID? = nil,
        transferredAt: Date? = nil,
        job: JobRecord
    ) {
        self.id = id
        self.supplier = supplier
        self.itemName = itemName
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transferredMaterialID = transferredMaterialID
        self.transferredAt = transferredAt
        self.job = job
    }
}
