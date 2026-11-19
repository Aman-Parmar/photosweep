import Foundation
import StoreKit

/// StoreKit 2, serverless. No RevenueCat, no receipt server.
/// Products (see SUBSCRIPTION_PLAN.md and Resources/PhotoSweep.storekit):
///   photosweep_pro_yearly   — auto-renewable, $29.99/year, 7-day trial
///   photosweep_pro_lifetime — non-consumable, $39.99 once
/// One Pro entitlement, not two feature sets. There is NO weekly plan
/// and NO monthly tier — the whole point of PhotoSweep is honest
/// pricing against the $5.99–$11.99/week traps the category is
/// complained about for. Free keeps the scan and review forever; Pro
/// adds depth only (unlimited deletes, large-video cleanup, export).
@MainActor
final class StoreManager: ObservableObject {
    static let yearlyProductID = "photosweep_pro_yearly"
    static let lifetimeProductID = "photosweep_pro_lifetime"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false

    private var updatesTask: Task<Void, Never>?

    /// Starts listening for StoreKit transaction updates. Called from
    /// `loadProducts()` (after init has completed) rather than from
    /// `init`, so the listener task never captures `self` before
    /// initialisation.
    private func startListening() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }

    func loadProducts() async {
        startListening()
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [
                Self.yearlyProductID, Self.lifetimeProductID,
            ])
            await refreshEntitlement()
        } catch {
            products = []
        }
    }

    func refreshEntitlement() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               [Self.yearlyProductID, Self.lifetimeProductID].contains(transaction.productID),
               transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlement()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}
