import Foundation

/// Raw transaction data for a tax advisor or accounting software — no
/// tax calculation happens here, only clean, correctly-structured data.
/// Matches the Trade Republic model: outside your core market, hand off
/// universal formats and let existing local tools apply local rules.
enum TaxDataExporter {
    /// Backs the optional "Your name" field in Settings — used only to
    /// personalize export filenames, nothing else.
    static let lastNameKey = "taxExportLastName"

    private static var fixedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Fixed, not locale-aware — this file is machine-parsed, so an
        // unambiguous ISO-style date matters more than local formatting.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    static func csv(for transactions: [Transaction]) -> String {
        var lines = ["Date,Merchant,Category,Type,Amount"]
        let formatter = fixedDateFormatter
        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            let categoryTitle = TransactionCategory(rawValue: transaction.category)?.title ?? transaction.category
            let fields = [
                formatter.string(from: transaction.date),
                transaction.merchant,
                categoryTitle,
                transaction.isIncome ? "Income" : "Expense",
                NSDecimalNumber(decimal: transaction.amount).stringValue
            ]
            lines.append(fields.map(csvField).joined(separator: ","))
        }
        // CRLF — RFC 4180's own line ending, safest default for the widest
        // range of spreadsheet/accounting import tools.
        return lines.joined(separator: "\r\n")
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// OFX 1.0.2 SGML — an old but still universally-ingested format for
    /// accounting/tax software (the format Trade Republic itself relies on
    /// for markets it doesn't localize tax rules for).
    static func ofx(for transactions: [Transaction]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let sorted = transactions.sorted { $0.date < $1.date }
        let now = dateFormatter.string(from: Date())
        let start = sorted.first.map { dateFormatter.string(from: $0.date) } ?? now
        let end = sorted.last.map { dateFormatter.string(from: $0.date) } ?? now
        // The real net cash flow over the exported period — a genuine
        // derived number, not a placeholder — used for the required
        // LEDGERBAL field (this account isn't a real bank feed, so there's
        // no true running balance to report otherwise).
        let netBalance = sorted.reduce(Decimal(0)) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }

        var transactionBlocks = ""
        for transaction in sorted {
            let signedAmount = transaction.isIncome ? transaction.amount : -transaction.amount
            let categoryTitle = TransactionCategory(rawValue: transaction.category)?.title ?? transaction.category
            transactionBlocks += """
            <STMTTRN>
            <TRNTYPE>\(transaction.isIncome ? "CREDIT" : "DEBIT")
            <DTPOSTED>\(dateFormatter.string(from: transaction.date))
            <TRNAMT>\(NSDecimalNumber(decimal: signedAmount).stringValue)
            <FITID>\(transaction.id.uuidString)
            <NAME>\(ofxEscape(transaction.merchant))
            <MEMO>\(ofxEscape(categoryTitle))
            </STMTTRN>

            """
        }

        return """
        OFXHEADER:100
        DATA:OFXSGML
        VERSION:102
        SECURITY:NONE
        ENCODING:USASCII
        CHARSET:1252
        COMPRESSION:NONE
        OLDFILEUID:NONE
        NEWFILEUID:NONE

        <OFX>
        <SIGNONMSGSRSV1>
        <SONRS>
        <STATUS>
        <CODE>0
        <SEVERITY>INFO
        </STATUS>
        <DTSERVER>\(now)
        <LANGUAGE>ENG
        </SONRS>
        </SIGNONMSGSRSV1>
        <BANKMSGSRSV1>
        <STMTTRNRS>
        <TRNUID>1
        <STATUS>
        <CODE>0
        <SEVERITY>INFO
        </STATUS>
        <STMTRS>
        <CURDEF>EUR
        <BANKACCTFROM>
        <BANKID>0
        <ACCTID>MONETA
        <ACCTTYPE>CHECKING
        </BANKACCTFROM>
        <BANKTRANLIST>
        <DTSTART>\(start)
        <DTEND>\(end)
        \(transactionBlocks)</BANKTRANLIST>
        <LEDGERBAL>
        <BALAMT>\(NSDecimalNumber(decimal: netBalance).stringValue)
        <DTASOF>\(now)
        </LEDGERBAL>
        </STMTRS>
        </STMTTRNRS>
        </BANKMSGSRSV1>
        </OFX>
        """
    }

    private static func ofxEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Filters the full ledger down to a chosen range — shared by both the
    /// raw CSV/OFX path and the Consolidated Statement PDF, so the two
    /// always agree on exactly which transactions were included.
    static func transactions(from all: [Transaction], in range: FiscalYear.Range) -> [Transaction] {
        all.filter { $0.date >= range.start && $0.date <= range.end }
    }

    /// Same grouping `FinanceStore.categoryBreakdown()` does for "this
    /// month," generalized to an arbitrary range — no `deltaVsAverage`,
    /// since there's no natural "average" to compare a whole chosen period
    /// against.
    static func categoryBreakdown(for transactions: [Transaction]) -> [CategoryBreakdownRow] {
        let expenses = transactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses, by: \.category)
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }
        return grouped.map { category, total in
            CategoryBreakdownRow(category: category, total: total, deltaVsAverage: nil)
        }.sorted { $0.total > $1.total }
    }

    /// `LastName_Dimera_TaxData_2025.csv` when a name is set, or just
    /// `Dimera_TaxData_2025.csv` when it isn't — no placeholder name is
    /// ever shown, since this app has no real stored identity by default.
    static func filename(format: TaxExportFormat, range: FiscalYear.Range) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startYear = calendar.component(.year, from: range.start)
        let endYear = calendar.component(.year, from: range.end)
        let yearLabel = startYear == endYear ? "\(startYear)" : "\(startYear)-\(endYear)"

        let rawName = UserDefaults.standard.string(forKey: lastNameKey)?.trimmingCharacters(in: .whitespaces) ?? ""
        let sanitizedName = rawName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let prefix = sanitizedName.isEmpty ? "" : "\(sanitizedName)_"

        return "\(prefix)Dimera_TaxData_\(yearLabel).\(format.fileExtension)"
    }
}
