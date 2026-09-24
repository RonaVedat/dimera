import SwiftUI

/// "What am I paying every month?" — the spending-control half of
/// Commitments. A large glanceable monthly total up top, then the list;
/// swipe to cancel matches every other list in this app.
struct SubscriptionsView: View {
    @EnvironmentObject private var store: FinanceStore
    @State private var showAddSheet = false
    @State private var detailEntry: RecurringEntry?

    /// Matches `GoalsView`'s own convention exactly — every plain (non-card)
    /// row gets this same explicit inset, so text at the top of the screen
    /// lines up with text in the rows below it instead of each defaulting
    /// to whatever `List` happens to pick.
    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 6, leading: MonetaMetrics.screenPadding, bottom: 6, trailing: MonetaMetrics.screenPadding)
    }

    var body: some View {
        List {
            Section {
                headerStat
                    .listRowBackground(Color.clear)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
            }

            Section {
                if store.subscriptions.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(store.subscriptions) { entry in
                        SubscriptionRow(entry: entry)
                            .listRowBackground(MonetaColor.canvas)
                            .listRowInsets(rowInsets)
                            .contentShape(Rectangle())
                            .onTapGesture { detailEntry = entry }
                            .deleteSwipeAction { store.deleteRecurring(entry) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MonetaColor.canvas)
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add subscription")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSubscriptionSheet()
        }
        .sheet(item: $detailEntry) { entry in
            SubscriptionDetailSheet(entry: entry)
        }
    }

    private var headerStat: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monthly cost")
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            Text(Currency.string(store.subscriptionsMonthlyTotal))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.3)
                .monospacedDigit()
                .foregroundStyle(MonetaColor.textPrimary)
        }
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MonetaColor.accent)
            }
            VStack(spacing: 4) {
                Text("No subscriptions yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("Add one and Dimera tracks what it's really costing you.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Haptics.selection()
                showAddSheet = true
            } label: {
                Text("Add Subscription")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonetaColor.canvas)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(MonetaColor.textPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .monetaCard()
        .accessibilityElement(children: .combine)
    }
}

private struct SubscriptionRow: View {
    let entry: RecurringEntry

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(style: .initial(entry.initial))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                if entry.isPaused {
                    Text("Paused")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MonetaColor.textTertiary)
                } else {
                    Text("\(entry.frequency.title) · Next charge: \(entry.dueLabel)")
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
            }
            Spacer(minLength: 6)
            Text(Currency.string(entry.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.isPaused ? MonetaColor.textTertiary : MonetaColor.textPrimary)
        }
        .padding(.vertical, 8)
        .opacity(entry.isPaused ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let store = FinanceStore()
    NavigationStack {
        SubscriptionsView()
    }
    .environmentObject(store)
    .task { await store.load() }
}
