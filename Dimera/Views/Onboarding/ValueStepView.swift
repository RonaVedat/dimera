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
            primaryTitle: isPurchasing ? String.localized("Processing…") : String.localized("Start Premium"),
            isPrimaryEnabled: !isPurchasing,
            primaryAction: startPurchase,
            secondaryTitle: String.localized("Not now"),
            secondaryAction: next
        ) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 12)

                Text("Here's your dashboard.")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if store.isLoading && store.transactions.isEmpty {
                    ProgressView()
                        .tint(MonetaColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    previewCard
                }

                Text("A preview with sample numbers — in the next step you'll make it yours.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)

                Divider().overlay(MonetaColor.separator)

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

                    PremiumFeatureList()
                    PremiumPriceTag()
                }
            }
        }
        .alert("Purchase failed", isPresented: showPurchaseError) {
            Button("Try Again", role: .cancel) {}
            Button("Continue with Free") { next() }
        } message: {
            Text(purchaseErrorMessage ?? "")
        }
    }

    private var showPurchaseError: Binding<Bool> {
        Binding(
            get: { purchaseErrorMessage != nil },
            set: { if !$0 { purchaseErrorMessage = nil } }
        )
    }

    /// Cancellation is silent (matches the App Store's own behavior); a
    /// pending purchase (Ask to Buy) resolves later via `StoreManager`'s
    /// transaction listener with no further action needed here; only a
    /// genuine failure surfaces an alert.
    private func startPurchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let outcome = try await storeManager.purchase()
                if outcome == .success {
                    Haptics.success()
                    next()
                }
            } catch {
                purchaseErrorMessage = String.localized("Something went wrong. Please try again.")
            }
        }
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
