import Foundation
import Observation

@MainActor @Observable
final class AccessStore {
    static let shared = AccessStore()
    private(set) var tier: AppTier = .free
    private(set) var product: PlusProduct?
    private(set) var isBusy = false
    private(set) var isLoadingProduct = false
    private(set) var isCheckingPurchases = true
    private(set) var message: String?
    private(set) var errorMessage: String?
    var selectedJobID: UUID? {
        didSet {
            if let selectedJobID { defaults.set(selectedJobID.uuidString, forKey: Self.selectionKey) }
            else { defaults.removeObject(forKey: Self.selectionKey) }
        }
    }
    private let defaults: UserDefaults
    private let storefront: any PlusStorefront
    private static let selectionKey = "freeEditableJobID"
    private var verifiedOwnership = false
    private var started = false
    private var ownershipRevision = 0
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    #if DEBUG
    private var testTier: AppTier?
    #endif

    init(defaults: UserDefaults = .standard, storefront: (any PlusStorefront)? = nil) {
        self.defaults = defaults
        self.storefront = storefront ?? ApplePlusStorefront()
        selectedJobID = defaults.string(forKey: Self.selectionKey).flatMap(UUID.init(uuidString:))
    }

    deinit { updatesTask?.cancel() }

    var hasPlus: Bool { tier == .plus }
    var policy: JobAccessPolicy { JobAccessPolicy(tier: tier, selectedJobID: selectedJobID) }
    var canPurchase: Bool { product != nil && !hasPlus && !verifiedOwnership && !isBusy && !isCheckingPurchases }

    func start() async {
        guard !started else { return }
        started = true
        updatesTask = storefront.observe { [weak self] in await self?.refreshPurchases() }
        await refreshPurchases()
        await loadProduct(clearError: false)
    }

    func refreshPurchases() async {
        ownershipRevision += 1
        let revision = ownershipRevision
        defer { if revision == ownershipRevision { isCheckingPurchases = false } }
        do {
            let owned = try await storefront.ownsPlus()
            guard revision == ownershipRevision else { return }
            verifiedOwnership = owned
            applyOwnership()
        } catch {
            guard revision == ownershipRevision else { return }
            // A verification failure never grants access and never changes customer data.
            errorMessage = error.localizedDescription
        }
    }

    func loadProduct(clearError: Bool = true) async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        if clearError { errorMessage = nil }
        defer { isLoadingProduct = false }
        do { product = try await storefront.loadProduct() }
        catch { errorMessage = error.localizedDescription }
    }

    func buyPlus() async {
        guard canPurchase else { return }
        isBusy = true
        message = nil
        errorMessage = nil
        clearTestTier()
        ownershipRevision += 1
        defer { isBusy = false }
        do {
            switch try await storefront.purchase() {
            case .purchased:
                // The adapter returns purchased only after verifying Apple's transaction.
                verifiedOwnership = true
                applyOwnership()
                await storefront.finishPurchase()
                message = String(localized: "Plus is now unlocked. Thank you!")
            case .pending:
                message = String(localized: "The purchase is awaiting approval. Plus will unlock automatically when Apple confirms it.")
            case .cancelled: break
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func restorePurchases() async {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        errorMessage = nil
        clearTestTier()
        ownershipRevision += 1
        defer { isBusy = false; isCheckingPurchases = false }
        do {
            try await storefront.restore()
            verifiedOwnership = try await storefront.ownsPlus()
            applyOwnership()
            isCheckingPurchases = false
            message = verifiedOwnership
                ? String(localized: "Your Plus purchase has been restored.")
                : String(localized: "No Plus purchase was found for this Apple Account. Your stored data is unchanged.")
        } catch { errorMessage = error.localizedDescription }
    }

    private func applyOwnership() {
        #if DEBUG
        if let testTier { tier = testTier; return }
        #endif
        tier = verifiedOwnership ? .plus : .free
    }

    private func clearTestTier() {
        #if DEBUG
        testTier = nil
        #endif
        applyOwnership()
    }

    #if DEBUG
    var testTierSelection: String { testTier?.rawValue ?? "apple" }
    func setTestTier(_ tier: AppTier) { testTier = tier; applyOwnership() }
    func selectTestTier(_ value: String) {
        testTier = AppTier(rawValue: value)
        applyOwnership()
    }
    #endif
}
