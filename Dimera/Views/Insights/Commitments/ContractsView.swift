import SwiftUI

/// "What am I locked into, and when can I get out?" — the obligations
/// half of Commitments. Each row leads with a status badge rather than
/// raw dates competing for attention.
struct ContractsView: View {
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
                if store.contracts.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(store.contracts) { entry in
                        ContractRow(entry: entry)
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
        .navigationTitle("Contracts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add contract")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddContractSheet()
        }
        .sheet(item: $detailEntry) { entry in
            ContractDetailSheet(entry: entry)
        }
    }

    private var headerStat: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active commitments")
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            Text("\(store.contracts.filter { $0.contractStatus != .cancelled }.count)")
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
                Image(systemName: "doc.text")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MonetaColor.accent)
            }
            VStack(spacing: 4) {
                Text("No contracts yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("Add one to track renewal dates and cancellation windows.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Haptics.selection()
                showAddSheet = true
            } label: {
                Text("Add Contract")
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

/// A stable presentation enum, not a string comparison — see
/// `RecurringEntry.contractStatus`.
struct ContractStatusBadge: View {
    let status: ContractStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .endingSoon {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
            }
            Text(label)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .active: return String.localized("Active")
        case .endingSoon: return String.localized("Ending soon")
        case .expired: return String.localized("Expired")
        case .cancelled: return String.localized("Cancelled")
        }
    }

    private var color: Color {
        switch status {
        case .active: return MonetaColor.textSecondary
        case .endingSoon: return MonetaColor.warning
        case .expired, .cancelled: return MonetaColor.textTertiary
        }
    }
}

private struct ContractRow: View {
    let entry: RecurringEntry

    private static func dateLabel(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.current.locale))
    }

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(style: .initial(entry.initial))
            VStack(alignment: .leading, spacing: 3) {
                ContractStatusBadge(status: entry.contractStatus)
                Text((entry.providerName?.isEmpty == false ? entry.providerName : nil) ?? entry.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                if let cancellationDeadline = entry.cancellationDeadline {
                    Text("Cancel by \(Self.dateLabel(cancellationDeadline))")
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                } else if let contractEndDate = entry.contractEndDate {
                    Text("Ends \(Self.dateLabel(contractEndDate))")
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Currency.string(entry.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.textPrimary)
                if entry.hasDocument {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(MonetaColor.gain)
                }
            }
        }
        .padding(.vertical, 8)
        .opacity(entry.contractStatus == .cancelled || entry.contractStatus == .expired ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let store = FinanceStore()
    NavigationStack {
        ContractsView()
    }
    .environmentObject(store)
    .task { await store.load() }
}
