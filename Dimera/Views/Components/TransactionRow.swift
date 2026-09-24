import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(style: transaction.isIncome ? .income : .initial(transaction.initial))
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text(TransactionCategory(rawValue: transaction.category)?.title ?? transaction.category)
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            Spacer(minLength: 8)
            Text(transaction.isIncome ? "+\(Currency.string(transaction.amount))" : "-\(Currency.string(transaction.amount))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.isIncome ? MonetaColor.gain : MonetaColor.textPrimary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
