import SwiftUI

/// The in-app paywall reached by tapping "Unlock with Premium" on a gated
/// feature, or "Upgrade to Family" in Settings (as opposed to
/// `ValueStepView`, its onboarding sibling). Real StoreKit 2 purchases —
/// Apple processes the payment and hands back a verified entitlement; this
/// app never sees a name, email, or card number.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var selection: PremiumPlan
    @State private var phase: Phase = .idle
    @State private var isRestoring = false
    @State private var purchaseErrorMessage: String?
    @State private var restoreMessage: String?

    private enum Phase: Equatable {
        case idle, purchasing, awaitingApproval
        case welcome(PremiumWelcomeVariant)
    }

    init(initialAudience: PremiumAudience = .justMe) {
        _selection = State(initialValue: initialAudience == .family ? .family : .yearly)
    }

    private var isUpgradingToFamily: Bool {
        storeManager.state.canUpgradeToFamily && selection == .family
    }

    var body: some View {
        switch phase {
        case .welcome(let variant):
            PremiumWelcomeSheet(variant: variant)
        case .awaitingApproval:
            awaitingApproval
        case .idle, .purchasing:
            paywall
        }
    }

    private var paywall: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PremiumHeaderBadge()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(isUpgradingToFamily ? String.localized("Share Premium with your family") : String.localized("Unlock Financial Intelligence"))
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(MonetaColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(isUpgradingToFamily
                             ? String.localized("You'll get a prorated refund for the rest of your current plan.")
                             : String.localized("Understand where your money goes."))
                            .font(.subheadline)
                            .foregroundStyle(MonetaColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PremiumFeatureList(includesFamily: selection == .family)

                    if storeManager.canMakePayments {
                        PremiumPlanPicker(selection: $selection)
                        PremiumLegalFooter(plan: selection)
                    } else {
                        PurchasesUnavailableNotice()
                    }

                    restoreButton
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(MonetaColor.canvas)
            .safeAreaInset(edge: .bottom) {
                if storeManager.canMakePayments {
                    purchaseButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if storeManager.products.isEmpty {
                    await storeManager.loadProducts()
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

    private var purchaseButton: some View {
        let isPurchasing = phase == .purchasing
        let canBuy = !isPurchasing && storeManager.products[selection] != nil
        return Button {
            startPurchase()
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .tint(MonetaColor.canvas)
                }
                Text(buttonTitle)
            }
        }
        .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: canBuy))
        .disabled(!canBuy)
        .padding(.horizontal, MonetaMetrics.screenPadding)
        .padding(.bottom, 16)
        .background(.bar)
    }

    private var buttonTitle: String {
        if phase == .purchasing { return String.localized("Processing…") }
        return selection == .family ? String.localized("Start Premium Family") : String.localized("Start Premium")
    }

    private var awaitingApproval: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "hourglass")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(MonetaColor.accent)
                    .accessibilityHidden(true)
                Text("Waiting for approval")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("You'll get Premium as soon as it's approved.")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, MonetaMetrics.screenPadding)
            .frame(maxWidth: .infinity)
            .background(MonetaColor.canvas)
            .safeAreaInset(edge: .bottom) {
                Button("Close") { dismiss() }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .padding(.horizontal, MonetaMetrics.screenPadding)
                    .padding(.bottom, 16)
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

    /// Cancelling is silent, as in the App Store itself. A pending purchase
    /// is Ask to Buy: the approval arrives later through `StoreManager`'s
    /// transaction listener, and `RootTabView` welcomes the person then.
    private func startPurchase() {
        guard phase == .idle else { return }
        phase = .purchasing
        Task {
            do {
                switch try await storeManager.purchase(selection) {
                case .success:
                    phase = PremiumWelcomeVariant(state: storeManager.state).map { .welcome($0) } ?? .idle
                case .pending:
                    phase = .awaitingApproval
                case .cancelled:
                    phase = .idle
                }
            } catch {
                phase = .idle
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
                if storeManager.state.isPremium {
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
