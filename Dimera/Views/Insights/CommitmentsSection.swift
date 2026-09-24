import SwiftUI

/// Two rows — Subscriptions (spending control) and Contracts (obligations
/// control) — replacing the old flat "Recurring payments" list that mixed
/// Netflix and the rent contract with no distinction. Each reads as a
/// small Apple-style tile: one large glanceable number, a quiet label,
/// the single gold accent already used throughout this app, no shadow —
/// the color/weight change carries the hierarchy, not decoration.
struct CommitmentsSection: View {
    @EnvironmentObject private var store: FinanceStore

    var body: some View {
        VStack(spacing: 10) {
            NavigationLink {
                SubscriptionsView()
            } label: {
                tile(
                    icon: "arrow.triangle.2.circlepath",
                    title: String.localized("Subscriptions"),
                    subtitle: String.localized("What you're paying, every month."),
                    value: Currency.string(store.subscriptionsMonthlyTotal),
                    caption: String.localized("\(store.subscriptions.filter { !$0.isPaused }.count) active")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ContractsView()
            } label: {
                tile(
                    icon: "doc.text",
                    title: String.localized("Contracts"),
                    subtitle: String.localized("Stay ahead of renewals."),
                    value: "\(store.contracts.filter { $0.contractStatus != .cancelled }.count)",
                    caption: String.localized("contracts")
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(icon: String, title: String, subtitle: String, value: String, caption: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MonetaColor.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(-0.3)
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.textPrimary)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonetaColor.textTertiary)
        }
        .padding(16)
        .monetaCard()
        .accessibilityElement(children: .combine)
    }
}
