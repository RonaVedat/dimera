import SwiftUI

/// Merges what used to be two screens — a dashboard preview, then a
/// separate Premium pitch — into one scroll: proof first, upsell second.
/// Only shown to users who chose "Create my dashboard" at the fork; someone
/// who chose "Connect bank now" sees `BankConnectionStepView` instead, not
/// this screen too — showing both to everyone was redundant friction.
struct ValueStepView: View {
    @EnvironmentObject private var store: FinanceStore
    @ObservedObject private var storeManager = StoreManager.shared
    let next: () -> Void
    var progress: Double?
    var stepLabel: String?
    var onBack: (() -> Void)?
    @State private var isPurchasing = false
    @State private var purchaseErrorMessage: String?
    @State private var selection: PremiumPlan = .yearly
    @State private var welcome: PremiumWelcomeVariant?
    @State private var isAwaitingApproval = false

    /// HIG: encourage a new subscription only when someone isn't already a
    /// subscriber — e.g. a family member installing Dimera for the first
    /// time already has Premium through their family.
    private var canSell: Bool {
        storeManager.state.shouldOfferPurchase && storeManager.canMakePayments
    }

    private var primaryTitle: String {
        if !canSell { return String.localized("Continue") }
        if isPurchasing { return String.localized("Processing…") }
        return selection == .family ? String.localized("Start Premium Family") : String.localized("Start Premium")
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return String.localized("Good morning")
        case 12..<18: return String.localized("Good afternoon")
        default: return String.localized("Good evening")
        }
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            stepLabel: stepLabel,
            onBack: onBack,
            primaryTitle: primaryTitle,
            isPrimaryEnabled: !canSell || (!isPurchasing && storeManager.products[selection] != nil),
            primaryAction: canSell ? startPurchase : next,
            secondaryTitle: canSell ? String.localized("Not now") : nil,
            secondaryAction: canSell ? next : nil
        ) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 12)

                Text("Here's your dashboard.")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if store.isLoading && store.transactions.isEmpty {
                    previewCardSkeleton
                        .transition(.opacity)
                } else {
                    previewCard
                        .transition(.opacity)
                }

                Text("A preview with sample numbers — in the next step you'll make it yours.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)

                Divider().overlay(MonetaColor.separator)

                if storeManager.state.shouldOfferPurchase {
                    premiumPitch
                } else {
                    alreadyPremium
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isLoading)
        }
        .alert("Purchase failed", isPresented: showPurchaseError) {
            Button("Try Again", role: .cancel) {}
            Button("Continue with Free") { next() }
        } message: {
            Text(purchaseErrorMessage ?? "")
        }
        .alert("Waiting for approval", isPresented: $isAwaitingApproval) {
            Button("OK") { next() }
        } message: {
            Text("You'll get Premium as soon as it's approved.")
        }
        .sheet(item: $welcome, onDismiss: next) { variant in
            PremiumWelcomeSheet(variant: variant)
        }
    }

    private var premiumPitch: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Then go further.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonetaColor.textSecondary)

            PremiumHeaderBadge()

            VStack(alignment: .leading, spacing: 6) {
                Text("Unlock Financial Intelligence")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Understand where your money goes.")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
            }

            PremiumFeatureList(includesFamily: selection == .family)

            if storeManager.canMakePayments {
                PremiumPlanPicker(selection: $selection)
                PremiumLegalFooter(plan: selection)
            } else {
                PurchasesUnavailableNotice()
            }
        }
    }

    private var alreadyPremium: some View {
        VStack(alignment: .leading, spacing: 16) {
            PremiumHeaderBadge()

            VStack(alignment: .leading, spacing: 6) {
                Text("You already have Premium")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if case .familyMember = storeManager.state {
                    Text("Included in your family's subscription.")
                        .font(.subheadline)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
            }

            PremiumFeatureList()
        }
    }

    private var showPurchaseError: Binding<Bool> {
        Binding(
            get: { purchaseErrorMessage != nil },
            set: { if !$0 { purchaseErrorMessage = nil } }
        )
    }

    /// Cancellation is silent (matches the App Store's own behavior). A
    /// pending purchase is Ask to Buy: say so, then continue — the approval
    /// arrives later via `StoreManager`'s transaction listener.
    private func startPurchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await storeManager.purchase(selection) {
                case .success:
                    if let variant = PremiumWelcomeVariant(state: storeManager.state) {
                        welcome = variant
                    } else {
                        next()
                    }
                case .pending:
                    isAwaitingApproval = true
                case .cancelled:
                    break
                }
            } catch {
                purchaseErrorMessage = String.localized("Something went wrong. Please try again.")
            }
        }
    }

    /// Shaped like `previewCard` itself, so nothing shifts once the sample
    /// numbers resolve.
    private var previewCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            SkeletonBlock(width: 100, height: 13)

            VStack(alignment: .leading, spacing: 2) {
                SkeletonBlock(width: 70, height: 13)
                SkeletonBlock(width: 160, height: 32)
            }

            Divider().overlay(MonetaColor.separator)

            SkeletonBlock(width: 80, height: 13)

            HStack(spacing: 10) {
                previewStatSkeleton
                previewStatSkeleton
            }

            VStack(alignment: .leading, spacing: 4) {
                SkeletonBlock(width: 90, height: 13)
                SkeletonBlock(width: 60, height: 24)
            }
        }
        .padding(18)
        .monetaCard()
        .skeletonShimmer()
    }

    private var previewStatSkeleton: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonBlock(width: 50, height: 11, surface: .card)
            SkeletonBlock(width: 70, height: 16, surface: .card)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Net worth")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                Text(Currency.string(store.netWorth))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.textPrimary)
            }

            Divider().overlay(MonetaColor.separator)

            Text("This month")
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)

            HStack(spacing: 10) {
                previewStat(title: String.localized("Income"), amount: store.monthIncome(), tint: MonetaColor.gain, signed: "+")
                previewStat(title: String.localized("Expenses"), amount: store.monthExpenses(), tint: MonetaColor.loss, signed: "-")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Savings rate")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                Text(store.savingsRate(), format: .percent.precision(.fractionLength(0)))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.accent)
            }
        }
        .padding(18)
        .monetaCard()
    }

    private func previewStat(title: String, amount: Decimal, tint: Color, signed: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            Text("\(signed)\(Currency.string(amount))")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MonetaColor.cardElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    let store = FinanceStore()
    ValueStepView(next: {})
        .environmentObject(store)
        .task { await store.load() }
}
