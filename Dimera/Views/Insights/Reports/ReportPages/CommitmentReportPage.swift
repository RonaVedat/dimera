import SwiftUI

/// Free — the same data behind Insights' Commitments section. One report,
/// two clearly labeled halves (Subscriptions, Contracts), mirroring the
/// exact mental-model split the in-app UI already teaches: "what am I
/// paying every month" vs. "what am I locked into." Superseded the old
/// flat "Contracts Report," which listed every recurring payment with no
/// distinction — misleading once Subscriptions/Contracts became a real,
/// separate concept elsewhere in the app.
struct CommitmentReportPage: View {
    let subscriptions: [RecurringEntry]
    let subscriptionsMonthlyTotal: Decimal
    let contracts: [RecurringEntry]

    /// Cancelled/expired contracts stay in the list (a real historical
    /// record worth keeping), but don't count toward a "what am I
    /// currently committed to" total — mirrors `subscriptionsMonthlyTotal`
    /// excluding paused entries for the same reason.
    private var activeContractsMonthlyTotal: Decimal {
        contracts
            .filter { $0.contractStatus == .active || $0.contractStatus == .endingSoon }
            .reduce(0) { $0 + $1.monthlyEquivalentAmount }
    }

    private var annualTotal: Decimal {
        (subscriptionsMonthlyTotal + activeContractsMonthlyTotal) * 12
    }

    private static var todayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: Date())
    }

    var body: some View {
        ReportPageChrome(reportTitle: String.localized("Commitment Report"), period: Self.todayLabel) {
            VStack(alignment: .leading, spacing: 24) {
                if subscriptions.isEmpty && contracts.isEmpty {
                    Text(String.localized("No subscriptions or contracts tracked yet."))
                        .font(.subheadline)
                        .foregroundStyle(ReportColor.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String.localized("Subscriptions"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(ReportColor.textSecondary)
                        if subscriptions.isEmpty {
                            Text(String.localized("No subscriptions tracked yet."))
                                .font(.subheadline)
                                .foregroundStyle(ReportColor.textSecondary)
                        } else {
                            entryList(subscriptions)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(String.localized("Contracts"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(ReportColor.textSecondary)
                        if contracts.isEmpty {
                            Text(String.localized("No contracts tracked yet."))
                                .font(.subheadline)
                                .foregroundStyle(ReportColor.textSecondary)
                        } else {
                            contractList(contracts)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String.localized("Annual commitment"))
                            .font(.footnote)
                            .foregroundStyle(ReportColor.textSecondary)
                        Text(Currency.string(annualTotal))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(ReportColor.accent)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func entryList(_ entries: [RecurringEntry]) -> some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReportColor.textPrimary)
                        Text(entry.isPaused ? String.localized("Paused") : entry.frequency.title)
                            .font(.footnote)
                            .foregroundStyle(ReportColor.textSecondary)
                    }
                    Spacer()
                    Text(Currency.string(entry.amount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.isPaused ? ReportColor.textSecondary : ReportColor.textPrimary)
                }
                .padding(.vertical, 10)
                Divider().overlay(ReportColor.separator)
            }
        }
    }

    private func contractList(_ entries: [RecurringEntry]) -> some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(statusLabel(for: entry.contractStatus))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(statusColor(for: entry.contractStatus))
                            Text((entry.providerName?.isEmpty == false ? entry.providerName : nil) ?? entry.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ReportColor.textPrimary)
                        }
                        Text(entry.frequency.title)
                            .font(.footnote)
                            .foregroundStyle(ReportColor.textSecondary)
                    }
                    Spacer()
                    Text(Currency.string(entry.amount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ReportColor.textPrimary)
                }
                .padding(.vertical, 10)
                Divider().overlay(ReportColor.separator)
            }
        }
    }

    private func statusLabel(for status: ContractStatus) -> String {
        switch status {
        case .active: return String.localized("Active")
        case .endingSoon: return String.localized("Ending soon")
        case .expired: return String.localized("Expired")
        case .cancelled: return String.localized("Cancelled")
        }
    }

    private func statusColor(for status: ContractStatus) -> Color {
        switch status {
        case .active: return ReportColor.textSecondary
        case .endingSoon: return ReportColor.warning
        case .expired, .cancelled: return ReportColor.textTertiary
        }
    }
}
