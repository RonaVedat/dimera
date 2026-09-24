import Foundation

/// How often a recurring entry repeats. Real pay cycles and bills aren't
/// all monthly — freelancers get paid biweekly, insurance is often
/// quarterly or yearly — so this is a first-class choice, not an
/// afterthought bolted onto "monthly."
enum RecurringFrequency: String, CaseIterable, Identifiable, Codable {
    case weekly = "Weekly"
    case biweekly = "Every 2 weeks"
    case monthly = "Monthly"
    case quarterly = "Every 3 months"
    case yearly = "Yearly"

    var id: String { rawValue }

    /// `rawValue` stays a fixed English key (`Codable`); this is what the
    /// UI shows.
    var title: String {
        switch self {
        case .weekly: return String.localized("Weekly")
        case .biweekly: return String.localized("Every 2 weeks")
        case .monthly: return String.localized("Monthly")
        case .quarterly: return String.localized("Every 3 months")
        case .yearly: return String.localized("Yearly")
        }
    }

    fileprivate func advance(_ date: Date, using calendar: Calendar) -> Date {
        switch self {
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly: return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

/// A subscription is a spending question ("what am I paying every
/// month?"); a contract is an obligations question ("what am I locked
/// into, and when can I get out?"). Same underlying data shape — a
/// recurring amount on a cadence — but different mental models, so this
/// is a real, first-class distinction rather than a display filter.
enum CommitmentKind: String, Codable {
    case subscription
    case contract
}

/// A contract's lifecycle, computed rather than stored (only `isCancelled`
/// is a real stored fact — `endingSoon`/`expired` derive from dates
/// already on the entry, so there's never a second source of truth that
/// can drift from the dates themselves). Mirrors the `HealthTier` pattern
/// already used for `FinancialHealth` — a stable enum for color-coding and
/// copy, never a string comparison.
enum ContractStatus {
    case active
    case endingSoon
    case expired
    case cancelled
}

/// A payment or income that repeats — rent, Netflix, a biweekly freelance
/// invoice, salary. Powers the "Upcoming" section on Home, so the app feels
/// proactive rather than purely retrospective.
struct RecurringEntry: Identifiable, Hashable {
    let id: UUID
    var name: String
    var amount: Decimal
    var isIncome: Bool
    var frequency: RecurringFrequency
    /// The first known occurrence; `nextDate` steps forward from here.
    var anchorDate: Date
    /// Set when this entry was spawned from "track it automatically" on a
    /// logged transaction. Deleting that transaction removes this entry too,
    /// so a stopped payment doesn't linger in Upcoming — nil for entries
    /// created directly (sample data, or a future "add recurring" flow).
    var originTransactionID: UUID?

    /// Subscription vs. contract — see `CommitmentKind`.
    var kind: CommitmentKind
    /// A paused subscription doesn't count toward spending totals or
    /// reminders, but stays visible ("I paused this in real life").
    var isPaused: Bool
    /// The actual company behind the entry ("Netflix," "Vodafone"),
    /// deliberately separate from `name` (the label the user chose, e.g.
    /// "Netflix Premium") — kept apart so grouping by provider later
    /// doesn't need to guess-parse a display string.
    var providerName: String?
    /// Contract-only fields — always `nil` for subscriptions.
    var contractEndDate: Date?
    var cancellationDeadline: Date?
    /// A custom one-time reminder date, independent of the app's global
    /// renewal lead-time setting.
    var reminderDate: Date?
    var providerNotes: String?
    /// Mirrors `Transaction.hasReceipt` exactly — the flag lives here, the
    /// actual file lives in `ContractDocumentStore`, keyed by this `id`.
    var hasDocument: Bool
    /// A cancelled contract stays in the list with a status badge rather
    /// than being deleted — the cancellation itself (when, under what
    /// terms) is a fact worth remembering, unlike a cancelled subscription.
    var isCancelled: Bool

    init(
        id: UUID = UUID(), name: String, amount: Decimal, isIncome: Bool,
        frequency: RecurringFrequency, anchorDate: Date, originTransactionID: UUID? = nil,
        kind: CommitmentKind = .subscription, isPaused: Bool = false, providerName: String? = nil,
        contractEndDate: Date? = nil, cancellationDeadline: Date? = nil, reminderDate: Date? = nil,
        providerNotes: String? = nil, hasDocument: Bool = false, isCancelled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isIncome = isIncome
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.originTransactionID = originTransactionID
        self.kind = kind
        self.isPaused = isPaused
        self.providerName = providerName
        self.contractEndDate = contractEndDate
        self.cancellationDeadline = cancellationDeadline
        self.reminderDate = reminderDate
        self.providerNotes = providerNotes
        self.hasDocument = hasDocument
        self.isCancelled = isCancelled
    }

    /// The next occurrence on or after today.
    var nextDate: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var candidate = cal.startOfDay(for: anchorDate)

        // Anchor dates are always recent (set at entry time), so this loops
        // only a handful of times even for weekly frequencies.
        var iterations = 0
        while candidate < today && iterations < 520 {
            candidate = frequency.advance(candidate, using: cal)
            iterations += 1
        }
        return candidate
    }

    var initial: String { String(name.first ?? "?") }

    /// Converts any billing cadence to its monthly equivalent — real unit
    /// math, not a usage claim — so totals across mixed frequencies (a
    /// monthly Netflix next to a yearly insurance bill) stay comparable.
    var monthlyEquivalentAmount: Decimal {
        switch frequency {
        case .weekly: return amount * 52 / 12
        case .biweekly: return amount * 26 / 12
        case .monthly: return amount
        case .quarterly: return amount / 3
        case .yearly: return amount / 12
        }
    }

    /// "Today", "Tomorrow", or "In 5 days" — proactive, human phrasing.
    /// The "In N days" case interpolates a plural argument so the String
    /// Catalog can supply correct plural forms per language (English/German
    /// have 2 forms, Russian has 4 — this is never hand-branched in Swift).
    var dueLabel: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: nextDate).day ?? 0
        switch days {
        case 0: return String.localized("Today")
        case 1: return String.localized("Tomorrow")
        default: return String.localized("In \(days) days")
        }
    }

    /// Only meaningful for `kind == .contract` — reads the same renewal
    /// lead-time setting `FinanceStore.renewalReviewCandidates` already
    /// uses, so "ending soon" means the same thing everywhere in the app,
    /// not a second, independently-tuned threshold.
    var contractStatus: ContractStatus {
        if isCancelled { return .cancelled }
        if let contractEndDate, contractEndDate < Date() { return .expired }
        if let cancellationDeadline {
            let leadDays = ReminderLeadTime(
                rawValue: UserDefaults.standard.object(forKey: ReminderSettingsKey.renewalLeadTimeDays) as? Int ?? ReminderLeadTime.oneDay.rawValue
            ) ?? .oneDay
            let cutoff = Calendar.current.date(byAdding: .day, value: leadDays.rawValue, to: Date()) ?? Date()
            if cancellationDeadline <= cutoff { return .endingSoon }
        }
        return .active
    }

    /// Builds an entry from a transaction the user is logging as it happens
    /// ("I just paid this, and it repeats monthly"). Anchors one period
    /// *past* that transaction, so `nextDate` points at the next occurrence
    /// rather than re-surfacing the payment that's already in Recent.
    static func afterLoggedTransaction(
        name: String, amount: Decimal, isIncome: Bool, frequency: RecurringFrequency,
        transactionDate: Date, originTransactionID: UUID?, kind: CommitmentKind = .subscription
    ) -> RecurringEntry {
        let cal = Calendar.current
        let anchor = frequency.advance(cal.startOfDay(for: transactionDate), using: cal)
        return RecurringEntry(
            name: name, amount: amount, isIncome: isIncome, frequency: frequency,
            anchorDate: anchor, originTransactionID: originTransactionID, kind: kind
        )
    }
}

// MARK: - Codable

/// Manual conformance, not synthesized: every field added after this
/// struct was first persisted must gracefully default when decoding data
/// saved before it existed, and synthesized `Decodable` throws on any
/// missing key rather than falling back — real schema evolution instead of
/// a crash (or a silent `try?` wipe back to sample data) the next time an
/// existing user's `LedgerStorage` blob is read.
extension RecurringEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, amount, isIncome, frequency, anchorDate, originTransactionID
        case kind, isPaused, providerName, contractEndDate, cancellationDeadline
        case reminderDate, providerNotes, hasDocument, isCancelled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Decimal.self, forKey: .amount)
        isIncome = try container.decode(Bool.self, forKey: .isIncome)
        frequency = try container.decode(RecurringFrequency.self, forKey: .frequency)
        anchorDate = try container.decode(Date.self, forKey: .anchorDate)
        originTransactionID = try container.decodeIfPresent(UUID.self, forKey: .originTransactionID)
        kind = try container.decodeIfPresent(CommitmentKind.self, forKey: .kind) ?? .subscription
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName)
        contractEndDate = try container.decodeIfPresent(Date.self, forKey: .contractEndDate)
        cancellationDeadline = try container.decodeIfPresent(Date.self, forKey: .cancellationDeadline)
        reminderDate = try container.decodeIfPresent(Date.self, forKey: .reminderDate)
        providerNotes = try container.decodeIfPresent(String.self, forKey: .providerNotes)
        hasDocument = try container.decodeIfPresent(Bool.self, forKey: .hasDocument) ?? false
        isCancelled = try container.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(amount, forKey: .amount)
        try container.encode(isIncome, forKey: .isIncome)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(anchorDate, forKey: .anchorDate)
        try container.encodeIfPresent(originTransactionID, forKey: .originTransactionID)
        try container.encode(kind, forKey: .kind)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encodeIfPresent(providerName, forKey: .providerName)
        try container.encodeIfPresent(contractEndDate, forKey: .contractEndDate)
        try container.encodeIfPresent(cancellationDeadline, forKey: .cancellationDeadline)
        try container.encodeIfPresent(reminderDate, forKey: .reminderDate)
        try container.encodeIfPresent(providerNotes, forKey: .providerNotes)
        try container.encode(hasDocument, forKey: .hasDocument)
        try container.encode(isCancelled, forKey: .isCancelled)
    }
}

enum RecurringSampleData {
    private static func date(daysFromNow: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
    }

    // "Telekom"/"HUK Insurance" are real brand names, left untranslated;
    // "Salary"/"Rent" are generic labels, localized like everything else.
    static var all: [RecurringEntry] {
        [
            RecurringEntry(name: "Telekom", amount: 49.99, isIncome: false, frequency: .monthly, anchorDate: date(daysFromNow: 8), kind: .subscription, providerName: "Telekom"),
            RecurringEntry(name: String.localized("Salary"), amount: 2_450, isIncome: true, frequency: .monthly, anchorDate: date(daysFromNow: 11)),
            RecurringEntry(
                name: "HUK Insurance", amount: 246.00, isIncome: false, frequency: .quarterly, anchorDate: date(daysFromNow: 13),
                kind: .contract, providerName: "HUK",
                contractEndDate: date(daysFromNow: 365), cancellationDeadline: date(daysFromNow: 60)
            ),
            RecurringEntry(name: String.localized("Rent"), amount: 950.00, isIncome: false, frequency: .monthly, anchorDate: date(daysFromNow: -15), kind: .contract, providerName: nil)
        ]
    }
}
