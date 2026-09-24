import Foundation

/// A lighter sibling of `ReceiptStore` — contracts are static reference
/// documents (view and re-share), not receipts that need OCR, compression
/// tiers, or duplicate detection. One file per contract, keyed by the
/// owning `RecurringEntry.id`, exactly like `ReceiptStore` keys by
/// `Transaction.id`.
actor ContractDocumentStore {
    static let shared = ContractDocumentStore()

    private let fileManager = FileManager.default

    private lazy var directory: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ContractDocuments", isDirectory: true)
    }()

    private init() {}

    /// `fileExtension` is whatever the source actually was — `pdf` from
    /// the Files picker, `jpg` from the camera or photo library — so the
    /// original document type is preserved rather than force-converted.
    func store(_ data: Data, for id: UUID, fileExtension: String) {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        // A contract can only ever have one attached document — replacing
        // it means clearing any previous file under a different extension.
        delete(for: id)
        try? data.write(to: url(for: id, fileExtension: fileExtension))
    }

    func document(for id: UUID) -> (data: Data, fileExtension: String)? {
        guard let match = existingFile(for: id) else { return nil }
        guard let data = try? Data(contentsOf: match) else { return nil }
        return (data, match.pathExtension)
    }

    func delete(for id: UUID) {
        guard let match = existingFile(for: id) else { return }
        try? fileManager.removeItem(at: match)
    }

    func deleteAll() {
        try? fileManager.removeItem(at: directory)
    }

    private func existingFile(for id: UUID) -> URL? {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }
        return contents.first { $0.deletingPathExtension().lastPathComponent == id.uuidString }
    }

    private func url(for id: UUID, fileExtension: String) -> URL {
        directory.appendingPathComponent("\(id.uuidString).\(fileExtension)")
    }
}
