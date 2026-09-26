import SwiftUI

struct StatTile: View {
    let title: String
    let amount: Decimal
    var tint: Color = MonetaColor.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            AmountText(amount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .monetaCard(radius: MonetaMetrics.tileRadius)
        .accessibilityElement(children: .combine)
    }
}
