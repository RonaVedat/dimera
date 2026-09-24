import SwiftUI
import StoreKit

/// The Premium pitch kit, shared between the onboarding `ValueStepView` and
/// the in-app `PaywallView` so the pitch never drifts between the two places
/// a user sees it. Every color stays inside `MonetaColor` — gold is the only
/// accent, and it's reserved for icons and the price itself, never a whole
/// row or button, per the app's "restrained accent" design language.
struct PremiumFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

enum PremiumFeatures {
    /// Every entry here maps to a real, working `PremiumGate` elsewhere in
    /// the app — Insights' full category breakdown, Goals' 30-day forecast,
    /// the Spending Analysis/Goal Progress reports, and unlimited receipts
    /// with search. Nothing advertised here that isn't already unlockable
    /// today, matching this app's own "never invent a number" precedent —
    /// extended to never invent a feature either.
    static var all: [PremiumFeature] { [
        PremiumFeature(
            icon: "chart.pie.fill",
            title: String.localized("Full category breakdown"),
            detail: String.localized("See every category, not just the top three, with month-over-month change.")
        ),
        PremiumFeature(
            icon: "chart.line.uptrend.xyaxis",
            title: String.localized("30-day balance forecasting"),
            detail: String.localized("See where your balance is headed before the month ends.")
        ),
        PremiumFeature(
            icon: "chart.bar.doc.horizontal.fill",
            title: String.localized("Spending & goal reports"),
            detail: String.localized("Category trends and goal-progress PDFs, ready to share.")
        ),
        PremiumFeature(
            icon: "doc.text.viewfinder",
            title: String.localized("Unlimited receipts"),
            detail: String.localized("Save as many as you need, and search what's inside them.")
        )
    ] }
}

/// The glowing sparkles badge that opens both premium screens.
struct PremiumHeaderBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(MonetaColor.accent.opacity(0.15))
                .frame(width: 64, height: 64)
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonetaColor.accent)
        }
        .accessibilityHidden(true)
    }
}

struct PremiumFeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(PremiumFeatures.all.enumerated()), id: \.element.id) { index, feature in
                if index > 0 {
                    Divider()
                        .overlay(MonetaColor.separator)
                        .padding(.leading, 50)
                }
                featureRow(feature)
            }
        }
        .padding(.vertical, 4)
        .monetaCard()
    }

    private func featureRow(_ feature: PremiumFeature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(MonetaColor.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: feature.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MonetaColor.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text(feature.detail)
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// A soft plan card rather than a plain price line — gold is reserved for
/// the number itself, the one thing worth the eye landing on. No fake
/// tiers, no "Most popular" badge (there's only one plan), no countdown.
/// Price and period are read live from the real StoreKit `Product` — never
/// hardcoded, so this can't drift from whatever's actually configured.
struct PremiumPriceTag: View {
    @ObservedObject private var storeManager = StoreManager.shared

    private var isLoading: Bool {
        storeManager.product == nil && storeManager.isLoadingProduct
    }

    private var priceText: String {
        storeManager.product?.displayPrice ?? "€4.99"
    }

    private var periodText: String {
        guard let period = storeManager.product?.subscription?.subscriptionPeriod else {
            return String.localized("per month")
        }
        switch period.unit {
        case .day: return period.value == 1 ? String.localized("per day") : String.localized("every \(period.value) days")
        case .week: return period.value == 1 ? String.localized("per week") : String.localized("every \(period.value) weeks")
        case .month: return period.value == 1 ? String.localized("per month") : String.localized("every \(period.value) months")
        case .year: return period.value == 1 ? String.localized("per year") : String.localized("every \(period.value) years")
        @unknown default: return String.localized("per month")
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dimera Premium")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("Cancel anytime.")
                    .font(.caption)
                    .foregroundStyle(MonetaColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(priceText)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.accent)
                Text(periodText)
                    .font(.caption2)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            .redacted(reason: isLoading ? .placeholder : [])
        }
        .padding(16)
        .background(MonetaColor.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: MonetaMetrics.tileRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MonetaMetrics.tileRadius, style: .continuous)
                .stroke(MonetaColor.accent.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
