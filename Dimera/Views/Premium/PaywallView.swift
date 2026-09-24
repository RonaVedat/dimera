import SwiftUI

/// The in-app paywall reached by tapping "Unlock with Premium" on a gated
/// feature (as opposed to `ValueStepView`, its onboarding sibling). Real
/// StoreKit 2 purchases — Apple processes the payment and hands back a
/// verified entitlement; this app never sees a name, email, or card number.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseErrorMessage: String?
    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PremiumHeaderBadge()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unlock Financial Intelligence")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(MonetaColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("Understand where your money goes.")
                            .font(.subheadline)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }

                    PremiumFeatureList()
                    PremiumPriceTag()

                    restoreButton
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(MonetaColor.canvas)
            .safeAreaInset(edge: .bottom) {
                Button {
                    startPurchase()
                } label: {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView()
                                .tint(MonetaColor.canvas)
                        }
                        Text(isPurchasing ? String.localized("Processing…") : String.localized("Start Premium"))
                    }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: !isPurchasing))
                .disabled(isPurchasing)
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.bottom, 16)
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if storeManager.product == nil {
                    await storeManager.loadProduct()
                }
            }
            .alert("Purchase failed", isPresented: showPurchaseError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseErrorMessage ?? "")
            }
            .alert("Nothing to restore", isPresented: showRestoreMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    private var restoreButton: some View {
        Button {
            restore()
        } label: {
            HStack(spacing: 6) {
                if isRestoring {
                    ProgressView().tint(MonetaColor.textSecondary)
                }
                Text("Restore Purchases")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(MonetaColor.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    private var showPurchaseError: Binding<Bool> {
        Binding(get: { purchaseErrorMessage != nil }, set: { if !$0 { purchaseErrorMessage = nil } })
    }

    private var showRestoreMessage: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }

    private func startPurchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let outcome = try await storeManager.purchase()
                if outcome == .success {
                    Haptics.success()
                    dismiss()
                }
            } catch {
                purchaseErrorMessage = String.localized("Something went wrong. Please try again.")
            }
        }
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await storeManager.restorePurchases()
                if UserDefaults.standard.bool(forKey: "isPremium") {
                    Haptics.success()
                    dismiss()
                } else {
                    restoreMessage = String.localized("We didn't find an active Dimera Premium subscription for this Apple ID.")
                }
            } catch {
                purchaseErrorMessage = String.localized("Something went wrong. Please try again.")
            }
        }
    }
}

#Preview {
    PaywallView()
}
