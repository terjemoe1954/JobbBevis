import Foundation
import StoreKit

struct PlusProduct: Equatable {
    let id: String
    let displayPrice: String
}

enum PlusPurchaseResult { case purchased, pending, cancelled }

@MainActor
protocol PlusStorefront {
    func loadProduct() async throws -> PlusProduct?
    func ownsPlus() async throws -> Bool
    func purchase() async throws -> PlusPurchaseResult
    func finishPurchase() async
    func restore() async throws
    func observe(_ refresh: @escaping @MainActor () async -> Void) -> Task<Void, Never>
}

enum PlusStoreError: LocalizedError {
    case unavailable, unverified, unexpected
    var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "Plus is currently unavailable. Please try again later.")
        case .unverified: String(localized: "Apple could not verify this purchase. Your stored data is unchanged. Please try restoring purchases.")
        case .unexpected: String(localized: "The purchase could not be completed. Please try again.")
        }
    }
}

@MainActor
final class ApplePlusStorefront: PlusStorefront {
    static let productID = "com.terjemoe.JobbBevis.plus"
    private var product: Product?
    private var purchaseToFinish: StoreKit.Transaction?

    func loadProduct() async throws -> PlusProduct? {
        let products = try await Product.products(for: [Self.productID])
        guard let product = products.first(where: { $0.id == Self.productID && $0.type == .nonConsumable }) else {
            self.product = nil
            return nil
        }
        self.product = product
        return PlusProduct(id: product.id, displayPrice: product.displayPrice)
    }

    func ownsPlus() async throws -> Bool {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Self.productID,
                   transaction.productType == .nonConsumable,
                   transaction.revocationDate == nil { owned = true }
            case .unverified(let transaction, _):
                if transaction.productID == Self.productID { throw PlusStoreError.unverified }
            }
        }
        return owned
    }

    func purchase() async throws -> PlusPurchaseResult {
        guard let product, product.id == Self.productID, product.type == .nonConsumable else {
            throw PlusStoreError.unavailable
        }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.productType == .nonConsumable,
                  transaction.revocationDate == nil else { throw PlusStoreError.unverified }
            purchaseToFinish = transaction
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw PlusStoreError.unexpected
        }
    }

    func finishPurchase() async {
        if let transaction = purchaseToFinish {
            await transaction.finish()
            purchaseToFinish = nil
        }
    }

    func restore() async throws { try await AppStore.sync() }

    func observe(_ refresh: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        Task {
            for await result in StoreKit.Transaction.updates {
                guard !Task.isCancelled else { break }
                switch result {
                case .verified(let transaction) where transaction.productID == Self.productID:
                    await refresh()
                    await transaction.finish()
                case .unverified(let transaction, _) where transaction.productID == Self.productID:
                    await refresh() // Show verification errors; never grant an unverified purchase.
                default: break
                }
            }
        }
    }
}
