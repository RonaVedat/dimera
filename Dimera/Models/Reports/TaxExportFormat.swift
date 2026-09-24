import Foundation

/// Raw-data export formats for the "Tax Prep Data" path — universally
/// accepted by accounting/tax software, deliberately not a proprietary
/// format. No PDF option here: a PDF is the "Consolidated Statement" path,
/// a different tier of this same flow.
enum TaxExportFormat: String, CaseIterable, Identifiable {
    case csv
    case ofx

    var id: String { rawValue }

    var title: String {
        switch self {
        case .csv: return "CSV"
        case .ofx: return "OFX"
        }
    }

    var subtitle: String {
        switch self {
        case .csv: return String.localized("Opens in Excel, Numbers, or any spreadsheet.")
        case .ofx: return String.localized("Imports directly into most accounting and tax software.")
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .ofx: return "ofx"
        }
    }
}
