import StoreKit

/// StoreKit 2 non-consumable IAP — "Remove Ads" ($3.99).
/// Rewarded ads are NOT affected: only banners and interstitials are gated by `adsRemoved`.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let productID  = "com.gravityflip.removeads"
    private static let udKey = "gf_adsRemoved"

    // MARK: - Published state

    @Published private(set) var product: Product?

    /// Single source of truth read by AdManager. Seeded from UserDefaults on launch
    /// for instant startup; verified against live entitlements on first run.
    @Published private(set) var adsRemoved: Bool

    enum PurchaseStatus: Equatable { case idle, purchasing, pending, restoring }
    @Published private(set) var purchaseStatus: PurchaseStatus = .idle

    // MARK: - Init

    private init() {
        adsRemoved = UserDefaults.standard.bool(forKey: Self.udKey)
        startTransactionListener()
        Task { await loadProduct() }
        Task { await verifyEntitlements() }
    }

    // MARK: - Entitlement verification (call at launch)

    func verifyEntitlements() async {
        var valid = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.productID,
               tx.revocationDate == nil {
                valid = true; break
            }
        }
        persist(adsRemoved: valid)
    }

    // MARK: - Product

    private func loadProduct() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    // MARK: - Purchase

    func buy() async {
        guard let product, purchaseStatus == .idle else { return }
        purchaseStatus = .purchasing
        defer { if purchaseStatus == .purchasing { purchaseStatus = .idle } }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    persist(adsRemoved: true)
                }
            case .pending:
                purchaseStatus = .pending   // resolved via Transaction.updates
                return
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            // Network error or StoreKit error — silently idle out.
        }
    }

    // MARK: - Restore

    func restore() async {
        guard purchaseStatus == .idle else { return }
        purchaseStatus = .restoring
        try? await AppStore.sync()
        await verifyEntitlements()
        purchaseStatus = .idle
    }

    // MARK: - Background transaction listener (deferred purchases, refunds)

    private func startTransactionListener() {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let tx) = result,
                      tx.productID == Self.productID else { continue }

                let revoked = tx.revocationDate != nil
                await MainActor.run {
                    self.persist(adsRemoved: !revoked)
                    if self.purchaseStatus == .pending { self.purchaseStatus = .idle }
                }
                await tx.finish()
            }
        }
    }

    // MARK: - Helpers

    private func persist(adsRemoved value: Bool) {
        adsRemoved = value
        UserDefaults.standard.set(value, forKey: Self.udKey)
    }

    /// Nonisolated read used by non-MainActor code (e.g. AdManager).
    /// UserDefaults is updated atomically in persist(adsRemoved:) on the main actor,
    /// so this always reflects the most recently committed value.
    nonisolated static var adsRemovedFast: Bool {
        UserDefaults.standard.bool(forKey: "gf_adsRemoved")
    }
}
