import Foundation
import UIKit

/// Everything kept about a scanned receipt besides the image bytes
/// themselves (those live as JPEG files under `ReceiptStore`'s directory).
/// `id` is always the owning `Transaction.id` — a receipt has exactly one
/// owner and there's never a second reference to keep in sync.
struct ReceiptMetadata: Codable, Identifiable, Hashable {
    let id: UUID
    var capturedAt: Date
    var suggestedMerchant: String?
    var suggestedAmount: Decimal?
    var suggestedDate: Date?
    /// What receipt search actually matches against — deliberately just the
    /// merchant/amount/date already surfaced to the user, never the full
    /// OCR dump. A receipt can contain card fragments, addresses, VAT
    /// numbers, or customer IDs; persisting the whole recognized-text blob
    /// "for search" would keep all of that around indefinitely for no real
    /// benefit, so the raw OCR output is discarded right after parsing.
    var searchableTokens: [String]
    /// A cheap perceptual fingerprint (see `ReceiptStore.fingerprint`), used
    /// only for the "you might have already added this" nudge — never
    /// anything sturdier than a same-device, same-library hint.
    var duplicateFingerprint: String
}

/// What `ReceiptStore.process(_:for:)` hands back to the
/// UI once the background pipeline finishes — everything the caller needs
/// to show suggestions and fill in fields, nothing about how it was made.
struct ReceiptProcessingResult {
    let thumbnail: UIImage
    let suggestedMerchant: String?
    let suggestedAmount: Decimal?
    let suggestedDate: Date?
    let possibleDuplicateOf: UUID?
}
