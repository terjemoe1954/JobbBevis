import Foundation
import SwiftData

@Model
final class PurchaseItem {
    @Attribute(.unique) var id: UUID
    var supplier: String
    var itemName: String
    var itemNumber: String?
    var quantity: Decimal
    var unit: String
    var unitPrice: Decimal
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var transferredMaterialID: UUID?
    var transferredAt: Date?
    var job: JobRecord

    var linkedMaterials: [MaterialEntry] {
        job.materialEntries.filter {
            $0.sourcePurchaseItemID == id
                || ($0.sourcePurchaseItemID == nil && transferredMaterialID == $0.id)
        }
    }

    var usedQuantity: Decimal { linkedMaterials.reduce(0) { $0 + $1.quantity } }
    var remainingQuantity: Decimal { max(0, quantity - usedQuantity) }
    var isTransferredToMaterials: Bool { usedQuantity >= quantity }

    var lineTotal: Decimal {
        quantity * unitPrice
    }

    var displayName: String {
        let number = itemNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return number.isEmpty ? itemName : "\(number) · \(itemName)"
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
        job: JobRecord,
        itemNumber: String? = nil
    ) {
        self.id = id
        self.supplier = supplier
        self.itemName = itemName
        self.itemNumber = itemNumber
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
