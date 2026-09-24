import Foundation
import UIKit
import Vision

/// The entire local receipt pipeline — compression, thumbnailing, on-device
/// OCR, duplicate detection, and file storage. An `actor` (this app's only
/// concurrency idiom is async/await — see `FinanceDataSource`,
/// `NotificationScheduler`) so every call already runs off the main actor:
/// the UI never blocks, with no manual dispatch-queue bookkeeping needed.
///
/// Everything here is on-device and offline. OCR uses Vision, never a
/// network call — matching this app's existing "AI = real local
/// computation" precedent (`TaxRadarScanner`, the spending-insight engine).
actor ReceiptStore {
    static let shared = ReceiptStore()

    private let fileManager = FileManager.default
    private var index: [UUID: ReceiptMetadata] = [:]
    private var didLoadIndex = false

    private lazy var rootDirectory: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Receipts", isDirectory: true)
    }()
    private lazy var optimizedDirectory = rootDirectory.appendingPathComponent("optimized", isDirectory: true)
    private lazy var thumbnailsDirectory = rootDirectory.appendingPathComponent("thumbnails", isDirectory: true)
    private lazy var indexURL = rootDirectory.appendingPathComponent("index.json")

    private init() {}

    // MARK: - Public API

    /// The whole background pipeline: resize down to an optimized copy and
    /// a thumbnail, run on-device OCR, and check the image against every
    /// stored fingerprint for a likely duplicate. Everything the caller
    /// needs to show suggestions comes back in one result — no
    /// intermediate state to poll.
    ///
    /// Everyone gets the same optimized-only storage for now — a
    /// full-resolution archive tier is a reasonable future Premium
    /// addition, but most users never zoom into a receipt, and the
    /// 1800px optimized copy is already more than legible. Not worth the
    /// extra on-disk copy and complexity until it's actually asked for.
    func process(_ image: UIImage, for id: UUID) async -> ReceiptProcessingResult {
        loadIndexIfNeeded()
        ensureDirectoriesExist()

        let optimized = Self.resized(image, maxDimension: 1800)
        let thumbnail = Self.resized(image, maxDimension: 200)
        let fingerprint = Self.fingerprint(of: image)
        // Excludes `id` itself — replacing a receipt with a new photo (the
        // "Retake"/"Choose from Library" context menu actions) shouldn't
        // ever flag itself as a duplicate of its own previous version.
        let duplicate = firstDuplicate(matching: fingerprint, excluding: id)

        if let data = optimized.jpegData(compressionQuality: 0.78) {
            try? data.write(to: optimizedURL(for: id))
        }
        if let data = thumbnail.jpegData(compressionQuality: 0.6) {
            try? data.write(to: thumbnailURL(for: id))
        }

        // The raw OCR text only ever exists transiently, right here — only
        // the parsed merchant/amount/date (already shown to the user as
        // suggestions) get persisted, never the full recognized-text dump.
        let recognizedText = await Self.recognizeText(in: image)
        let suggestion = Self.parse(recognizedText)

        index[id] = ReceiptMetadata(
            id: id, capturedAt: Date(),
            suggestedMerchant: suggestion.merchant, suggestedAmount: suggestion.amount,
            suggestedDate: suggestion.date,
            searchableTokens: Self.searchableTokens(merchant: suggestion.merchant, amount: suggestion.amount, date: suggestion.date),
            duplicateFingerprint: fingerprint
        )
        saveIndex()

        return ReceiptProcessingResult(
            thumbnail: thumbnail, suggestedMerchant: suggestion.merchant,
            suggestedAmount: suggestion.amount, suggestedDate: suggestion.date,
            possibleDuplicateOf: duplicate
        )
    }

    func thumbnail(for id: UUID) -> UIImage? {
        loadImage(at: thumbnailURL(for: id))
    }

    func optimizedImage(for id: UUID) -> UIImage? {
        loadImage(at: optimizedURL(for: id))
    }

    func delete(for id: UUID) {
        loadIndexIfNeeded()
        for url in [optimizedURL(for: id), thumbnailURL(for: id)] {
            try? fileManager.removeItem(at: url)
        }
        index[id] = nil
        saveIndex()
    }

    func deleteAll() {
        try? fileManager.removeItem(at: rootDirectory)
        index = [:]
        didLoadIndex = true
    }

    var receiptCount: Int {
        loadIndexIfNeeded()
        return index.count
    }

    func possibleDuplicate(of image: UIImage) -> UUID? {
        loadIndexIfNeeded()
        return firstDuplicate(matching: Self.fingerprint(of: image))
    }

    /// Plain-text search over each receipt's merchant/amount/date tokens —
    /// backs the Premium "receipt content search" nudge in `ActivityView`.
    func search(_ query: String) -> [UUID] {
        loadIndexIfNeeded()
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        return index.values
            .filter { $0.searchableTokens.contains { $0.contains(needle) } }
            .map(\.id)
    }

    // MARK: - Files

    private func ensureDirectoriesExist() {
        for url in [optimizedDirectory, thumbnailsDirectory] {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func optimizedURL(for id: UUID) -> URL { optimizedDirectory.appendingPathComponent("\(id.uuidString).jpg") }
    private func thumbnailURL(for id: UUID) -> URL { thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg") }

    private func loadImage(at url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Index persistence

    private func loadIndexIfNeeded() {
        guard !didLoadIndex else { return }
        didLoadIndex = true
        guard let data = try? Data(contentsOf: indexURL),
              let entries = try? JSONDecoder().decode([ReceiptMetadata].self, from: data) else { return }
        index = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    private func saveIndex() {
        ensureDirectoriesExist()
        guard let data = try? JSONEncoder().encode(Array(index.values)) else { return }
        try? data.write(to: indexURL)
    }

    private func firstDuplicate(matching fingerprint: String, excluding excludedID: UUID? = nil) -> UUID? {
        index.values.first { $0.id != excludedID && Self.hammingDistance($0.duplicateFingerprint, fingerprint) <= 6 }?.id
    }

    // MARK: - Resizing

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return image }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    // MARK: - OCR

    private static func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["de-DE", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    /// Best-effort heuristics over the recognized text — these are always
    /// surfaced to the user as editable suggestions, never applied silently.
    private static let totalKeywords = ["total", "summe", "gesamt", "betrag", "montant"]
    private static let amountPattern = /\d{1,3}(?:[.,]\d{3})*[.,]\d{2}/

    private static func parse(_ text: String) -> (merchant: String?, amount: Decimal?, date: Date?) {
        let lines = text.split(separator: "\n").map(String.init)

        // A receipt's own name is almost always the first legible line —
        // logos and headers OCR as text before any numbers do.
        let merchant = lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.count >= 2 && trimmed.rangeOfCharacter(from: .letters) != nil
        }?.trimmingCharacters(in: .whitespaces)

        let amount = amountFromKeywordLine(lines) ?? largestAmount(in: lines)

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let date = detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.date

        return (merchant, amount, date)
    }

    private static func amountFromKeywordLine(_ lines: [String]) -> Decimal? {
        for line in lines {
            let lower = line.lowercased()
            guard totalKeywords.contains(where: lower.contains) else { continue }
            if let match = line.firstMatch(of: amountPattern) {
                return decimal(from: String(match.0))
            }
        }
        return nil
    }

    /// Falls back to the largest currency-shaped number on the receipt —
    /// the total is almost always the biggest line item.
    private static func largestAmount(in lines: [String]) -> Decimal? {
        lines.flatMap { line in
            line.matches(of: amountPattern).compactMap { decimal(from: String($0.0)) }
        }.max()
    }

    /// The only things kept for search — merchant name, amount, and date,
    /// already lowercased/normalized so `search(_:)` is a plain substring
    /// check with nothing left over from the original OCR pass.
    private static func searchableTokens(merchant: String?, amount: Decimal?, date: Date?) -> [String] {
        var tokens: [String] = []
        if let merchant { tokens.append(merchant.lowercased()) }
        if let amount { tokens.append(NSDecimalNumber(decimal: amount).stringValue) }
        if let date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            tokens.append(formatter.string(from: date))
        }
        return tokens
    }

    private static func decimal(from token: String) -> Decimal? {
        // "1.234,56" (German) and "1,234.56" (US) both reduce to the same
        // value once the thousands separator is stripped and the decimal
        // separator normalized to ".".
        let normalized: String
        if let lastComma = token.lastIndex(of: ","), let lastDot = token.lastIndex(of: "."), lastComma > lastDot {
            normalized = token.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if token.contains(",") && !token.contains(".") {
            normalized = token.replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = token.replacingOccurrences(of: ",", with: "")
        }
        return Decimal(string: normalized)
    }

    // MARK: - Duplicate detection (average hash)

    /// Downscales to 8×8 grayscale and thresholds each pixel against the
    /// image's own average brightness — a classic, cheap "aHash". Good
    /// enough to catch the exact same photo or a near-identical retake;
    /// nothing more is needed for a "you might have added this" nudge.
    private static func fingerprint(of image: UIImage) -> String {
        let dimension = 8
        guard let cgImage = image.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let context = CGContext(
                  data: nil, width: dimension, height: dimension, bitsPerComponent: 8,
                  bytesPerRow: dimension, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
              )
        else { return "" }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))
        guard let data = context.data else { return "" }
        let pixels = data.bindMemory(to: UInt8.self, capacity: dimension * dimension)

        let average = (0..<(dimension * dimension)).reduce(0) { $0 + Int(pixels[$1]) } / (dimension * dimension)
        return (0..<(dimension * dimension)).map { Int(pixels[$0]) >= average ? "1" : "0" }.joined()
    }

    private static func hammingDistance(_ a: String, _ b: String) -> Int {
        guard a.count == b.count, !a.isEmpty else { return .max }
        return zip(a, b).filter { $0 != $1 }.count
    }
}
