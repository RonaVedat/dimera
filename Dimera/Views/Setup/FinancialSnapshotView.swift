import SwiftUI
import UIKit

/// First-time setup, straight after onboarding: four rough numbers, thirty
/// seconds, and the dashboard exists. The net-worth preview at the top
/// recalculates live as they type — understanding stays primary even while
/// entering data.
struct FinancialSnapshotView: View {
    @EnvironmentObject private var store: FinanceStore
    let onComplete: () -> Void

    @State private var cashText = ""
    @State private var savingsText = ""
    @State private var investmentsText = ""
    @State private var debtText = ""
    @FocusState private var focusedField: Field?

    private enum Field { case cash, savings, investments, debt }

    private var cash: Decimal { parseAmountOrZero(cashText) }
    private var savings: Decimal { parseAmountOrZero(savingsText) }
    private var investments: Decimal { parseAmountOrZero(investmentsText) }
    private var debt: Decimal { parseAmountOrZero(debtText) }

    private var previewNetWorth: Decimal { cash + savings + investments - debt }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Let's create your financial picture.")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(MonetaColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("Rough numbers are fine — you can adjust anything later.")
                            .font(.subheadline)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                    .padding(.top, 28)

                    netWorthPreview

                    VStack(spacing: 10) {
                        snapshotField(String.localized("Cash available"), text: $cashText, field: .cash, icon: "eurosign")
                        snapshotField(String.localized("Savings"), text: $savingsText, field: .savings, icon: "banknote")
                        snapshotField(String.localized("Investments"), text: $investmentsText, field: .investments, icon: "chart.line.uptrend.xyaxis")
                        snapshotField(String.localized("Debt (optional)"), text: $debtText, field: .debt, icon: "creditcard")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                Button {
                    create()
                } label: {
                    Text("Create my dashboard")
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())

                Text("Stays on this device. Nothing is uploaded.")
                    .font(.caption)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .background(MonetaColor.canvas)
        .onAppear { focusedField = .cash }
    }

    private var netWorthPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Your net worth")
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            Text(Currency.string(previewNetWorth))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(previewNetWorth >= 0 ? MonetaColor.textPrimary : MonetaColor.loss)
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: previewNetWorth).doubleValue))
                .animation(.snappy(duration: 0.25), value: previewNetWorth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .monetaCard()
        .accessibilityElement(children: .combine)
    }

    private func snapshotField(_ title: String, text: Binding<String>, field: Field, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textPrimary)
            Spacer()
            HStack(spacing: 2) {
                Text("€")
                    .foregroundStyle(MonetaColor.textSecondary)
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 60)
                    .focused($focusedField, equals: field)
                    .foregroundStyle(MonetaColor.textPrimary)
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
        }
        .padding(14)
        .monetaCard(radius: MonetaMetrics.tileRadius)
    }

    private func create() {
        store.applySnapshot(FinancialSnapshot(cash: cash, savings: savings, investments: investments, debt: debt))
        Haptics.success()
        onComplete()
    }

    private func parseAmountOrZero(_ text: String) -> Decimal {
        parseAmount(text) ?? 0
    }
}

#Preview {
    FinancialSnapshotView(onComplete: {})
        .environmentObject(FinanceStore())
}
