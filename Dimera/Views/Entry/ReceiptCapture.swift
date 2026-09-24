import SwiftUI
import PhotosUI
import VisionKit

/// Everything "Add Receipt" needs, self-contained: the empty-state menu row
/// or the attached thumbnail, both pickers, the full-screen viewer, the
/// free-tier cap paywall, and the duplicate-receipt nudge. `AddExpenseForm`
/// and `EditTransactionSheet` each just drop this in with a transaction id
/// and a `hasReceipt` binding — the instant-thumbnail / silent-background-
/// processing / user-never-sees-a-spinner behavior all lives here once.
struct ReceiptAttachmentSection: View {
    @EnvironmentObject private var store: FinanceStore
    @AppStorage("isPremium") private var isPremium = false

    let transactionID: UUID
    @Binding var hasReceipt: Bool
    var onSuggestion: (ReceiptProcessingResult) -> Void = { _ in }
    /// The banner claims fields got filled in — true only where `onSuggestion`
    /// actually fills something. `EditTransactionSheet`'s fields are already
    /// populated from the existing transaction, so there's nothing to fill;
    /// showing the banner there would be a false claim.
    var showsSuggestionBanner = true

    @State private var thumbnail: UIImage?
    @State private var isProcessing = false
    @State private var showSuggestionBanner = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFullScreen = false
    @State private var showCapacityPaywall = false
    @State private var duplicateTransaction: Transaction?

    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail {
                ReceiptThumbnailRow(image: thumbnail, isProcessing: isProcessing) { showFullScreen = true }
                    .contextMenu {
                        Button { requestCapture(useCamera: true) } label: { Label("Retake Photo", systemImage: "camera") }
                        Button { requestCapture(useCamera: false) } label: { Label("Choose from Library", systemImage: "photo.on.rectangle") }
                        Button(role: .destructive) { removeReceipt() } label: { Label("Remove Receipt", systemImage: "trash") }
                    }
            } else {
                AddReceiptMenuRow(
                    onTakePhoto: { requestCapture(useCamera: true) },
                    onChooseLibrary: { requestCapture(useCamera: false) }
                )
            }
            if showSuggestionBanner {
                ReceiptSuggestionBanner()
            }
        }
        .task { await loadExistingThumbnailIfNeeded() }
        .sheet(isPresented: $showCamera) {
            CameraPicker(onPick: handlePicked)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(onPick: handlePicked)
        }
        .sheet(isPresented: $showCapacityPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            ReceiptFullScreenView(transactionID: transactionID)
        }
        .alert(
            "You may have already added this",
            isPresented: Binding(
                get: { duplicateTransaction != nil },
                set: { if !$0 { duplicateTransaction = nil } }
            )
        ) {
            Button("Add Anyway") { duplicateTransaction = nil }
            Button("Cancel", role: .cancel) { removeReceipt() }
        } message: {
            if let duplicateTransaction {
                Text("This looks like a receipt you already saved for \(duplicateTransaction.merchant) · \(Currency.string(duplicateTransaction.amount)). Add it again anyway?")
            }
        }
    }

    private func loadExistingThumbnailIfNeeded() async {
        guard hasReceipt, thumbnail == nil else { return }
        thumbnail = await ReceiptStore.shared.thumbnail(for: transactionID)
    }

    private func requestCapture(useCamera: Bool) {
        Task {
            let count = await ReceiptStore.shared.receiptCount
            // A replace/retake on a receipt this transaction already has
            // doesn't grow the count (same id overwrites) — only a brand
            // new attachment should ever hit the cap. 100 comfortably
            // covers a heavy month (groceries + restaurants + fuel) without
            // ever being the reason someone upgrades — Premium's pitch is
            // unlimited history and search, not a low wall.
            if !isPremium && !hasReceipt && count >= 100 {
                showCapacityPaywall = true
            } else if useCamera {
                showCamera = true
            } else {
                showPhotoPicker = true
            }
        }
    }

    private func handlePicked(_ image: UIImage) {
        // The thumbnail appears immediately — everything after this runs
        // silently in the background (`ReceiptStore` is an actor). Most
        // captures finish well under a second; the "Processing receipt…"
        // state only becomes visible if it's actually going to take a
        // moment, so the common case shows no loading state at all.
        thumbnail = image
        hasReceipt = true
        let revealIndicator = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            isProcessing = true
        }
        Task {
            let result = await ReceiptStore.shared.process(image, for: transactionID)
            revealIndicator.cancel()
            isProcessing = false
            thumbnail = result.thumbnail
            if showsSuggestionBanner, result.suggestedMerchant != nil || result.suggestedAmount != nil {
                showSuggestionBanner = true
            }
            onSuggestion(result)
            if let duplicateID = result.possibleDuplicateOf {
                duplicateTransaction = store.transactions.first { $0.id == duplicateID }
            }
        }
    }

    private func removeReceipt() {
        thumbnail = nil
        hasReceipt = false
        showSuggestionBanner = false
        Task { await ReceiptStore.shared.delete(for: transactionID) }
    }
}

// MARK: - Rows

private struct AddReceiptMenuRow: View {
    let onTakePhoto: () -> Void
    let onChooseLibrary: () -> Void

    var body: some View {
        Menu {
            Button { onTakePhoto() } label: { Label("Take Photo", systemImage: "camera") }
            Button { onChooseLibrary() } label: { Label("Choose from Library", systemImage: "photo.on.rectangle") }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paperclip")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Add Receipt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.textPrimary)
                    Text("Snap a photo or pick one from your library.")
                        .font(.caption)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            .padding(14)
            .monetaCard(radius: MonetaMetrics.tileRadius)
        }
        .buttonStyle(.plain)
    }
}

private struct ReceiptThumbnailRow: View {
    let image: UIImage
    let isProcessing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    if isProcessing {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.35))
                            .frame(width: 44, height: 44)
                        ProgressView().tint(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Receipt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.textPrimary)
                    Text(isProcessing ? "Processing receipt…" : "Tap to view")
                        .font(.caption)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            .padding(10)
            .monetaCard(radius: MonetaMetrics.tileRadius)
        }
        .buttonStyle(.plain)
    }
}

private struct ReceiptSuggestionBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MonetaColor.gain)
            VStack(alignment: .leading, spacing: 1) {
                Text("Receipt scanned")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("We filled in the merchant, amount, and date — double-check before saving.")
                    .font(.caption)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .monetaCard(radius: MonetaMetrics.tileRadius)
    }
}

// MARK: - Full-screen viewer

/// Wallet-attachment-style: the image, edge to edge, one close button.
/// Nothing else competes with it.
private struct ReceiptFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    let transactionID: UUID

    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .white.opacity(0.25))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            image = await ReceiptStore.shared.optimizedImage(for: transactionID)
        }
    }
}

// MARK: - Camera (VisionKit document scan)

/// Apple's own document-scanning camera — edge detection, deskewing, and
/// cropping happen automatically, which produces far cleaner OCR input than
/// a handheld photo. Requires `NSCameraUsageDescription`.
struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                parent.onPick(scan.imageOfPage(at: 0))
            }
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo library (PHPicker — no permission prompt, runs out-of-process)

struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                guard let image = image as? UIImage else { return }
                DispatchQueue.main.async { self.parent.onPick(image) }
            }
        }
    }
}
