import Foundation
import SwiftData

@MainActor
enum MaterialTransferService {
    enum TransferError: LocalizedError {
        case invalidQuantity, changed, identityConflict, unitMismatch, missingSource
        var errorDescription: String? {
            switch self {
            case .invalidQuantity: String(localized: "Enter a quantity greater than zero.")
            case .changed: String(localized: "The purchase item or its usage has changed. Close this form and try again.")
            case .identityConflict: String(localized: "This registration could not be confirmed. Check the materials before trying again.")
            case .unitMismatch: String(localized: "The material and purchase item must use the same unit. Unlink the material before changing its unit.")
            case .missingSource: String(localized: "The purchase item is no longer available.")
            }
        }
    }

    /// Legacy one-to-one links remain readable; new registrations carry their source ID.
    static func linkedMaterials(for item: PurchaseItem) -> [MaterialEntry] {
        item.job.materialEntries.filter {
            $0.sourcePurchaseItemID == item.id
                || ($0.sourcePurchaseItemID == nil && item.transferredMaterialID == $0.id)
        }
    }

    @discardableResult
    static func registerUsage(
        for item: PurchaseItem, quantity: Decimal, operationID: UUID,
        expectedUsed: Decimal, expectedUpdatedAt: Date, in context: ModelContext
    ) throws -> MaterialEntry {
        guard !quantity.isNaN, quantity > 0 else { throw TransferError.invalidQuantity }
        // A repeated submission with the same ID acknowledges the saved registration.
        let id = operationID
        if let existing = try context.fetch(FetchDescriptor<MaterialEntry>(predicate: #Predicate { $0.id == id })).first {
            guard existing.job.id == item.job.id, existing.sourcePurchaseItemID == item.id,
                  existing.quantity == quantity else { throw TransferError.identityConflict }
            return existing
        }
        let itemID = item.id
        guard try context.fetch(FetchDescriptor<PurchaseItem>(predicate: #Predicate { $0.id == itemID })).first != nil else {
            throw TransferError.missingSource
        }
        guard item.updatedAt == expectedUpdatedAt, item.usedQuantity == expectedUsed else { throw TransferError.changed }
        guard linkedMaterials(for: item).allSatisfy({ $0.unit == item.unit }) else { throw TransferError.unitMismatch }
        let material = MaterialEntry(
            id: operationID, name: item.itemName, quantity: quantity, unit: item.unit,
            note: item.note, job: item.job, unitPrice: item.unitPrice, sourcePurchaseItemID: item.id, itemNumber: item.itemNumber
        )
        context.insert(material)
        item.job.materialEntries.append(material)
        item.updatedAt = .now
        item.job.updatedAt = .now
        do {
            try context.save()
            return material
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Explicit linking only: names never determine identity. Caller saves/rolls back.
    static func link(_ material: MaterialEntry, to item: PurchaseItem?) throws {
        if let item {
            guard material.job.id == item.job.id else { throw TransferError.missingSource }
            guard material.unit == item.unit else { throw TransferError.unitMismatch }
        }
        let previousID = material.sourcePurchaseItemID
        for candidate in material.job.purchaseItems {
            if candidate.transferredMaterialID == material.id {
                candidate.transferredMaterialID = nil
                candidate.transferredAt = nil
                candidate.updatedAt = .now
            }
            if candidate.id == previousID || candidate.id == item?.id { candidate.updatedAt = .now }
        }
        material.sourcePurchaseItemID = item?.id
    }
}
