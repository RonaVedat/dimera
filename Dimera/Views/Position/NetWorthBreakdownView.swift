import SwiftUI

/// The drill-down behind the dashboard tiles: every asset and liability,
/// individually visible and deletable, arranged as the actual net-worth
/// equation so the math is never a mystery. Reached by tapping any position
/// tile or the debt row — a quick look, then back to status.
struct NetWorthBreakdownView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var addKind: AddEntrySheet.Kind?
    @State private var editingAsset: Asset?
    @State private var editingLiability: Liability?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    equationCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "eurosign")
                            .font(.subheadline)
                            .foregroundStyle(MonetaColor.textSecondary)
                            .frame(width: 20)
                        Text("Cash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonetaColor.textPrimary)
                        Spacer()
                        Text(Currency.string(store.cash))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(MonetaColor.textPrimary)
                    }
                    .listRowBackground(MonetaColor.card)
                } footer: {
                    Text("Moves automatically with the income and expenses you log.")
                }

                assetsSection
                liabilitiesSection

                Section {
                } footer: {
                    Text("Every change here moves the net-worth line on your dashboard instantly.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(MonetaColor.canvas)
            .navigationTitle("Net worth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $addKind) { kind in
                AddEntrySheet(kind: kind)
            }
            .sheet(item: $editingAsset) { asset in
                EditAssetSheet(asset: asset)
            }
            .sheet(item: $editingLiability) { liability in
                EditLiabilitySheet(liability: liability)
            }
        }
    }

    // MARK: - Equation

    private var equationCard: some View {
        VStack(spacing: 10) {
            equationRow(sign: nil, label: String.localized("Cash"), amount: store.cash, tint: MonetaColor.textPrimary)
            equationRow(sign: "+", label: String.localized("Assets"), amount: store.assetsTotal, tint: MonetaColor.textPrimary)
            equationRow(sign: "−", label: String.localized("Debt"), amount: store.debtTotal, tint: store.debtTotal > 0 ? MonetaColor.loss : MonetaColor.textSecondary)
            Divider().overlay(MonetaColor.separator)
            HStack {
                Text("Net worth")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Spacer()
                Text(Currency.string(store.netWorth))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(store.netWorth >= 0 ? MonetaColor.textPrimary : MonetaColor.loss)
            }
        }
        .padding(16)
        .monetaCard()
        .accessibilityElement(children: .combine)
    }

    private func equationRow(sign: String?, label: String, amount: Decimal, tint: Color) -> some View {
        HStack {
            Text(sign.map { "\($0) \(label)" } ?? label)
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)
            Spacer()
            Text(Currency.string(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    // MARK: - Assets

    private var assetsSection: some View {
        Section {
            if store.assets.isEmpty {
                Text("Nothing here yet — savings accounts, ETFs, crypto.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .listRowBackground(MonetaColor.card)
            } else {
                ForEach(store.assets) { asset in
                    Button {
                        editingAsset = asset
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: asset.kind.systemImage)
                                .font(.subheadline)
                                .foregroundStyle(MonetaColor.accent)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(asset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MonetaColor.textPrimary)
                                if asset.name.localizedCaseInsensitiveCompare(asset.kind.title) != .orderedSame {
                                    Text(asset.kind.title)
                                        .font(.footnote)
                                        .foregroundStyle(MonetaColor.textSecondary)
                                }
                            }
                            Spacer()
                            Text(Currency.string(asset.value))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(MonetaColor.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MonetaColor.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(MonetaColor.card)
                    .accessibilityElement(children: .combine)
                    .deleteSwipeAction { store.deleteAsset(asset) }
                }
            }

            addButton(title: String.localized("Add asset"), kind: .asset)
        } header: {
            Text("Assets · \(Currency.string(store.assetsTotal))")
        } footer: {
            Text("Tap a row to edit, swipe to remove.")
        }
    }

    // MARK: - Liabilities

    private var liabilitiesSection: some View {
        Section {
            if store.liabilities.isEmpty {
                Text("Debt-free — nothing counts against you.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .listRowBackground(MonetaColor.card)
            } else {
                ForEach(store.liabilities) { liability in
                    Button {
                        editingLiability = liability
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard")
                                .font(.subheadline)
                                .foregroundStyle(MonetaColor.loss)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(liability.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MonetaColor.textPrimary)
                                if let payment = liability.monthlyPayment {
                                    Text("\(Currency.string(payment))/mo")
                                        .font(.footnote)
                                        .foregroundStyle(MonetaColor.textSecondary)
                                }
                            }
                            Spacer()
                            Text(Currency.string(liability.amount))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(MonetaColor.loss)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MonetaColor.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(MonetaColor.card)
                    .accessibilityElement(children: .combine)
                    .deleteSwipeAction { store.deleteLiability(liability) }
                }
            }

            addButton(title: String.localized("Add liability"), kind: .liability)
        } header: {
            Text("Liabilities · \(Currency.string(store.debtTotal))")
        } footer: {
            Text("Tap a row to edit, swipe to remove.")
        }
    }

    private func addButton(title: String, kind: AddEntrySheet.Kind) -> some View {
        Button {
            addKind = kind
        } label: {
            Label(title, systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonetaColor.accent)
        }
        .listRowBackground(MonetaColor.card)
    }
}

#Preview {
    let store = FinanceStore()
    Color.clear.sheet(isPresented: .constant(true)) {
        NetWorthBreakdownView()
            .environmentObject(store)
            .task { await store.load() }
    }
}
