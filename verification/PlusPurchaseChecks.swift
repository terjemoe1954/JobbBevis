import Foundation

@MainActor private final class FakePlusStorefront: PlusStorefront {
    var offeredProduct: PlusProduct? = PlusProduct(id: ApplePlusStorefront.productID, displayPrice: "299,00 kr")
    var owned = false
    var verificationFails = false
    var restoreFails = false
    var result = PlusPurchaseResult.purchased
    var buys = 0
    var finishes = 0
    var restores = 0
    var observer: (@MainActor () async -> Void)?
    func loadProduct() async throws -> PlusProduct? { offeredProduct }
    func ownsPlus() async throws -> Bool {
        if verificationFails { throw PlusStoreError.unverified }
        return owned
    }
    func purchase() async throws -> PlusPurchaseResult {
        buys += 1
        if verificationFails { throw PlusStoreError.unverified }
        if case .purchased = result { owned = true }
        return result
    }
    func finishPurchase() async { finishes += 1 }
    func restore() async throws {
        restores += 1
        if restoreFails { throw PlusStoreError.unexpected }
    }
    func observe(_ refresh: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        observer = refresh
        return Task {}
    }
    func notify() async { await observer?() }
}

@main struct PlusPurchaseChecks {
    @MainActor static func main() async throws {
        let suite = "JobbBevis-Purchase-Test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let selected = UUID()
        let fake = FakePlusStorefront()
        let store = AccessStore(defaults: defaults, storefront: fake)
        store.selectedJobID = selected
        await store.start()
        assert(!store.hasPlus && store.canPurchase && !store.isCheckingPurchases)
        assert(store.product?.displayPrice == "299,00 kr")
        fake.result = .cancelled
        await store.buyPlus()
        assert(!store.hasPlus && store.errorMessage == nil && fake.finishes == 0)
        fake.result = .pending
        await store.buyPlus()
        assert(!store.hasPlus && store.message != nil && fake.finishes == 0)
        fake.owned = true
        await fake.notify()
        assert(store.hasPlus) // Approved later, without another purchase tap.
        fake.owned = false
        await fake.notify()
        assert(!store.hasPlus && store.selectedJobID == selected) // Revocation changes access only.
        fake.result = .purchased
        await store.buyPlus()
        assert(store.hasPlus && fake.finishes == 1 && !store.isBusy)
        let buys = fake.buys
        await store.buyPlus()
        assert(fake.buys == buys) // Already owned: no repeated purchase.
        let relaunched = AccessStore(defaults: defaults, storefront: fake)
        await relaunched.start()
        assert(relaunched.hasPlus && relaunched.selectedJobID == selected)
        fake.owned = false
        await relaunched.refreshPurchases()
        assert(!relaunched.hasPlus)
        fake.owned = true
        await relaunched.restorePurchases()
        assert(relaunched.hasPlus && fake.restores == 1)
        fake.owned = false
        await relaunched.restorePurchases()
        assert(!relaunched.hasPlus && relaunched.message != nil)
        fake.restoreFails = true
        await relaunched.restorePurchases()
        assert(!relaunched.hasPlus && relaunched.errorMessage != nil && !relaunched.isBusy)
        fake.restoreFails = false
        fake.verificationFails = true
        await relaunched.buyPlus()
        assert(!relaunched.hasPlus && relaunched.errorMessage != nil && fake.finishes == 1)
        let unverified = AccessStore(defaults: defaults, storefront: fake)
        await unverified.start()
        assert(!unverified.hasPlus && unverified.errorMessage != nil)
        assert(unverified.selectedJobID == selected)
        fake.verificationFails = false
        fake.offeredProduct = nil
        let unavailable = AccessStore(defaults: defaults, storefront: fake)
        await unavailable.start()
        assert(!unavailable.canPurchase)
        let priorBuys = fake.buys
        await unavailable.buyPlus()
        assert(fake.buys == priorBuys)
        print("PASS: purchase cancellation/pending/approval/success, verified startup, restore found/missing/error, unverified rejection, revocation, duplicate protection, unavailable product and preserved free-job selection")
    }
}
