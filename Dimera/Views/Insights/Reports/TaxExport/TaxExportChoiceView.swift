import SwiftUI

/// Tier 1 — "who is this export for?" Two paths, no third option: a
/// human-readable summary for the user themselves, or raw structured data
/// for whoever actually files the taxes. Never says "tax return" anywhere
/// in this flow, and carries the same quiet legal disclaimer throughout
/// (see `legalDisclaimer`) rather than a scary modal.
struct TaxExportChoiceView: View {
    @Environment(\.dismiss) private var dismiss

    static let legalDisclaimer = String.localized("This report aggregates your financial activity to assist with your tax filings. Dimera does not provide localized tax advice. Please consult a local tax professional in your jurisdiction to ensure compliance.")

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                optionCard(
                    title: String.localized("Consolidated Statement"),
                    subtitle: String.localized("A clean annual summary of your income and expenses."),
                    icon: "doc.text.image",
                    destination: .consolidatedStatement
                )
                optionCard(
                    title: String.localized("Raw Data Export"),
                    subtitle: String.localized("CSV or OFX, ready for your accountant's software."),
                    icon: "tablecells",
                    destination: .rawData(.csv)
                )

                Spacer(minLength: 0)

                Text(Self.legalDisclaimer)
                    .font(.caption)
                    .foregroundStyle(MonetaColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(MonetaMetrics.screenPadding)
            .padding(.top, 8)
            .background(MonetaColor.canvas)
            .navigationTitle("Tax Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func optionCard(title: String, subtitle: String, icon: String, destination: TaxExportDestination) -> some View {
        NavigationLink {
            TaxExportDateRangeView(destination: destination)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
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
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            .padding(16)
            .monetaCard()
        }
        .buttonStyle(.plain)
    }
}
