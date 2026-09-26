import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var store: FinanceStore
    @AppStorage("isPremium") private var isPremium = false
    @State private var query = ""
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction?
    @State private var showPaywall = false
    @State private var receiptMatchCount = 0

    private var groups: [(label: String, items: [Transaction])] {
        guard !query.isEmpty else { return store.transactionsByDay }
        return store.transactionsByDay.compactMap { group in
            let filtered = group.items.filter {
                $0.merchant.localizedCaseInsensitiveContains(query) ||
                $0.category.localizedCaseInsensitiveContains(query)
            }
            return filtered.isEmpty ? nil : (group.label, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.label) { group in
                    Section {
                        ForEach(group.items) { transaction in
                            TransactionRow(transaction: transaction)
                                .listRowBackground(MonetaColor.canvas)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTransaction = transaction }
                                .deleteSwipeAction { store.deleteTransaction(transaction) }
                        }
                    } header: {
                        Text(group.label)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .adaptiveContentWidth()
            .background(MonetaColor.canvas)
            .navigationTitle("Activity")
            // Explicit `.navigationBarDrawer` placement, not `.automatic` —
            // in a NavigationSplitView, `.automatic` can hand the search
            // field to the sidebar's own toolbar instead of this detail
            // view's. Transactions search is scoped to this screen, so it
            // belongs inline here, not sidebar-wide.
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add transaction")
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddEntrySheet()
            }
            .sheet(item: $editingTransaction) { transaction in
                EditTransactionSheet(transaction: transaction)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .safeAreaInset(edge: .bottom) {
                if !isPremium, !query.isEmpty, receiptMatchCount > 0 {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("A receipt might match — unlock Receipt Search", systemImage: "lock.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MonetaColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MonetaMetrics.tileRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, MonetaMetrics.screenPadding)
                    .padding(.bottom, 6)
                }
            }
            .task(id: query) {
                guard !isPremium, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                    receiptMatchCount = 0
                    return
                }
                let matches = await ReceiptStore.shared.search(query)
                let alreadyShown = Set(groups.flatMap { $0.items.map(\.id) })
                receiptMatchCount = matches.filter { !alreadyShown.contains($0) }.count
            }
            .overlay {
                if groups.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else if store.transactions.isEmpty {
                    ContentUnavailableView {
                        Label("Your financial story starts here", systemImage: "sparkles")
                    } description: {
                        Text("Every expense and income you add builds your picture.")
                    } actions: {
                        Button {
                            showAddTransaction = true
                        } label: {
                            Text("Add expense")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(MonetaColor.canvas)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(MonetaColor.textPrimary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    let store = FinanceStore()
    ActivityView()
        .environmentObject(store)
        .task { await store.load() }
}
