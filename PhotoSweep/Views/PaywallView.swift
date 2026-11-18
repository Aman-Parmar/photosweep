import StoreKit
import SwiftUI

/// Paywall: one Pro entitlement, two ways to buy it. No weekly plan,
/// no monthly tier — that is the point of this app. Prices are also
/// shown as plain text, so the screenshot lane shows pricing even
/// when the StoreKit configuration has not loaded yet.
struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("PhotoSweep Pro")
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier("paywall-title")
                    Text("Free scans and reviews forever. Pro is for people with a lot to clean.")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([
                            "Unlimited deletes (free: 20 photos)",
                            "Large-video cleanup",
                            "Export a cleanup report",
                            "No ads, no account — now or ever",
                        ], id: \.self) { feature in
                            Label(feature, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                    .font(.subheadline)
                    // Plain-text prices: always visible, even before
                    // StoreKit products load (e.g. in screenshots).
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yearly — $29.99/year, 7-day free trial")
                            .font(.headline)
                        Text("Lifetime — $39.99 once, yours forever")
                            .font(.headline)
                        Text("No weekly plan. No monthly plan. Ever.")
                            .font(.subheadline.bold())
                    }
                    .accessibilityIdentifier("paywall-prices")
                    if store.products.isEmpty {
                        Text(store.isLoading ? "Loading prices…" : "Prices will load when the App Store is reachable. The prices above are the App Store prices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.products) { product in
                            Button {
                                Task {
                                    do {
                                        try await store.purchase(product)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName)
                                            .font(.headline)
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("paywall-buy-\(product.id)")
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    .buttonStyle(.bordered)
                    Text("Payment is handled by Apple. Cancel anytime in Settings — the trial ends automatically if you cancel before day 7. Deleting photos is always your choice; Pro never auto-deletes anything.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
