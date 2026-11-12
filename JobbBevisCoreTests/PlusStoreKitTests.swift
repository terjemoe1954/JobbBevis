import XCTest
import StoreKit
import StoreKitTest
@testable import JobbBevis

final class PlusStoreKitTests: XCTestCase {
    @MainActor
    func testPurchaseRestoreAndRevocationWithAppleStoreKit() async throws {
        guard ProcessInfo.processInfo.environment["JOBBBEVIS_STOREKIT_TEST"] == "1" else {
            throw XCTSkip("Use the JobbBevis StoreKit Local scheme for local purchase integration tests")
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "JobbBevisPlus", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let suite = "JobbBevis-StoreKit-Test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selected = UUID()
        let store = AccessStore(defaults: defaults, storefront: ApplePlusStorefront())
        store.selectedJobID = selected
        await store.start()
        let _ = try XCTUnwrap(store.product, store.errorMessage ?? "Local StoreKit product unavailable")
        XCTAssertFalse(store.hasPlus)
        XCTAssertTrue(store.canPurchase)
        await store.buyPlus()
        XCTAssertTrue(store.hasPlus, store.errorMessage ?? "No verified purchase")
        XCTAssertFalse(store.canPurchase)
        let relaunched = AccessStore(defaults: defaults, storefront: ApplePlusStorefront())
        await relaunched.start()
        XCTAssertTrue(relaunched.hasPlus)
        await relaunched.restorePurchases()
        XCTAssertTrue(relaunched.hasPlus, relaunched.errorMessage ?? "Restore failed")
        let transactions = session.allTransactions()
        let purchased = try XCTUnwrap(transactions.first)
        try session.refundTransaction(identifier: purchased.identifier)
        for _ in 0..<40 {
            await store.refreshPurchases()
            if !store.hasPlus { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertFalse(store.hasPlus)
        XCTAssertEqual(store.selectedJobID, selected)
    }
}
