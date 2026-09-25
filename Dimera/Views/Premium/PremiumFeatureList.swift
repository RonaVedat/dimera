import SwiftUI
import StoreKit

/// The Premium pitch kit, shared between the onboarding `ValueStepView` and
/// the in-app `PaywallView` so the pitch never drifts between the two places
/// a user sees it. Every color stays inside `MonetaColor` — the accent is
/// reserved for icons, prices and the selected plan, never a whole button,
/// per the app's "restrained accent" design language.
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

    static var family: PremiumFeature {
        PremiumFeature(
            icon: "person.2.fill",
            title: String.localized("Share with up to 5 family members"),
            detail: String.localized("Through Apple Family Sharing. Everyone keeps their own private data.")
        )
    }
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
    var includesFamily = false

    private var features: [PremiumFeature] {
        includesFamily ? [PremiumFeatures.family] + PremiumFeatures.all : PremiumFeatures.all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
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

// MARK: - Plan picker

enum PremiumAudience: Hashable {
    case justMe, family
}

/// Plan choice with progressive disclosure: a "Just me | Family" switch
/// first, so no more than two prices are ever on screen at once. Every
/// price and period comes live from StoreKit — never hardcoded, so this
/// can't drift from what's configured in App Store Connect.
struct PremiumPlanPicker: View {
    @ObservedObject private var storeManager = StoreManager.shared
    @Binding var selection: PremiumPlan

    private var audience: Binding<PremiumAudience> {
        Binding(
            get: { selection == .family ? .family : .justMe },
            set: { newValue in
                Haptics.selection()
                selection = newValue == .family ? .family : .yearly
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if storeManager.products.isEmpty {
                if storeManager.isLoadingProducts {
                    placeholderCard
                } else {
                    unavailableCard
                }
            } else {
                if storeManager.familyPlanAvailable {
                    Picker("Plan", selection: audience) {
                        Text("Just me").tag(PremiumAudience.justMe)
                        Text("Family").tag(PremiumAudience.family)
                    }
                    .pickerStyle(.segmented)
                }

                if selection == .family, let family = storeManager.products[.family] {
                    planCard(plan: .family, product: family, subtitle: String.localized("Up to 6 people"))
                    Text("Shared through Apple Family Sharing. Everyone uses Premium on their own device — nobody can see anyone else's finances.")
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if let yearly = storeManager.products[.yearly] {
                        planCard(plan: .yearly, product: yearly, subtitle: monthlyEquivalent(of: yearly), badge: savingsBadge)
                    }
                    if let monthly = storeManager.products[.monthly] {
                        planCard(plan: .monthly, product: monthly, subtitle: String.localized("Cancel anytime."))
                    }
                }
            }
        }
        .onAppear(perform: normalizeSelection)
        .onChange(of: storeManager.products.count) { _, _ in normalizeSelection() }
    }

    /// Falls back to whatever actually loaded — e.g. if the family product
    /// isn't available, a stale `.family` selection can't leave the
    /// purchase button pointing at nothing.
    private func normalizeSelection() {
        guard !storeManager.products.isEmpty, storeManager.products[selection] == nil else { return }
        selection = [.yearly, .monthly, .family].first { storeManager.products[$0] != nil } ?? selection
    }

    private func planCard(plan: PremiumPlan, product: Product, subtitle: String?, badge: String? = nil) -> some View {
        let isSelected = selection == plan
        return Button {
            Haptics.selection()
            selection = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? MonetaColor.accent : MonetaColor.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonetaColor.textPrimary)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(MonetaColor.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(MonetaColor.accent.opacity(0.15), in: Capsule())
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? MonetaColor.accent : MonetaColor.textPrimary)
                    Text(product.perPeriodText)
                        .font(.caption2)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
            }
            .padding(16)
            .frame(minHeight: 44)
            .background(
                isSelected ? MonetaColor.accent.opacity(0.10) : MonetaColor.card,
                in: RoundedRectangle(cornerRadius: MonetaMetrics.tileRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MonetaMetrics.tileRadius, style: .continuous)
                    .stroke(isSelected ? MonetaColor.accent.opacity(0.5) : MonetaColor.separator, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var savingsBadge: String? {
        guard let monthly = storeManager.products[.monthly]?.price,
              let yearly = storeManager.products[.yearly]?.price,
              monthly > 0 else { return nil }
        let fullYear = monthly * 12
        let saving = NSDecimalNumber(decimal: (fullYear - yearly) / fullYear * 100).intValue
        return saving >= 1 ? String.localized("Save \(saving)%") : nil
    }

    private func monthlyEquivalent(of yearly: Product) -> String {
        let perMonth = (yearly.price / 12).formatted(yearly.priceFormatStyle)
        return String.localized("\(perMonth) per month, billed yearly")
    }

    private var placeholderCard: some View {
        HStack {
            Text("Dimera Premium")
            Spacer()
            Text(verbatim: "€0.00")
        }
        .font(.subheadline.weight(.semibold))
        .padding(16)
        .monetaCard(radius: MonetaMetrics.tileRadius)
        .redacted(reason: .placeholder)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load prices. Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try Again") {
                Task { await storeManager.loadProducts() }
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .monetaCard(radius: MonetaMetrics.tileRadius)
    }
}

// MARK: - Required sign-up terms

/// HIG "Making signup effortless": billing amount and period, how renewal
/// works, and links to the Terms of Use and Privacy Policy on the sign-up
/// screen itself.
struct PremiumLegalFooter: View {
    @ObservedObject private var storeManager = StoreManager.shared
    let plan: PremiumPlan

    var body: some View {
        VStack(spacing: 8) {
            if let product = storeManager.products[plan] {
                Text("Renews at \(product.displayPrice) \(product.perPeriodText) until cancelled. Cancel anytime in Settings.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 16) {
                Link("Terms of Use", destination: AppLinks.termsOfUse)
                if let privacy = AppLinks.privacyPolicy {
                    Link("Privacy Policy", destination: privacy)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .font(.caption)
        .foregroundStyle(MonetaColor.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Explains why nothing can be bought instead of showing a purchase button
/// that can't work (HIG: display your store only when people can make
/// payments — Screen Time or device management can block purchases).
struct PurchasesUnavailableNotice: View {
    var body: some View {
        Label("Purchases are turned off on this device. You can keep using Dimera for free.", systemImage: "hand.raised")
            .font(.footnote)
            .foregroundStyle(MonetaColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .monetaCard(radius: MonetaMetrics.tileRadius)
    }
}

extension Product {
    var perPeriodText: String {
        guard let period = subscription?.subscriptionPeriod else {
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
}
