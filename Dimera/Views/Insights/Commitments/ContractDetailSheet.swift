import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Status badge, the editable contract fields, and the four actions the
/// spec asked for: Upload Document, Set Reminder, Provider details, and
/// Cancel Contract (a soft cancel — see `RecurringEntry.isCancelled`).
struct ContractDetailSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let entry: RecurringEntry

    @State private var name: String
    @State private var providerName: String
    @State private var amountText: String
    @State private var frequency: RecurringFrequency
    @State private var hasEndDate: Bool
    @State private var contractEndDate: Date
    @State private var hasCancellationDeadline: Bool
    @State private var cancellationDeadline: Date
    @State private var hasReminder: Bool
    @State private var reminderDate: Date
    @State private var providerNotes: String
    @State private var hasDocument: Bool
    @State private var showCancelConfirm = false
    @State private var showCancelledConfirmation = false

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var showDocumentViewer = false

    init(entry: RecurringEntry) {
        self.entry = entry
        _name = State(initialValue: entry.name)
        _providerName = State(initialValue: entry.providerName ?? "")
        _amountText = State(initialValue: NSDecimalNumber(decimal: entry.amount).stringValue)
        _frequency = State(initialValue: entry.frequency)
        _hasEndDate = State(initialValue: entry.contractEndDate != nil)
        _contractEndDate = State(initialValue: entry.contractEndDate ?? Date())
        _hasCancellationDeadline = State(initialValue: entry.cancellationDeadline != nil)
        _cancellationDeadline = State(initialValue: entry.cancellationDeadline ?? Date())
        _hasReminder = State(initialValue: entry.reminderDate != nil)
        _reminderDate = State(initialValue: entry.reminderDate ?? Date())
        _providerNotes = State(initialValue: entry.providerNotes ?? "")
        _hasDocument = State(initialValue: entry.hasDocument)
    }

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ContractStatusBadge(status: entry.contractStatus)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AmountEntryField(text: $amountText, focused: $amountFocused)

                    VStack(spacing: 10) {
                        EntryFieldRow(icon: "doc.text") {
                            TextField("Name", text: $name)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                        EntryFieldRow(icon: "building.2") {
                            TextField("Provider (optional)", text: $providerName)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                    }

                    frequencyPicker

                    VStack(spacing: 10) {
                        optionalDateRow(title: String.localized("Contract Ends"), isOn: $hasEndDate, date: $contractEndDate)
                        optionalDateRow(title: String.localized("Cancellation Deadline"), isOn: $hasCancellationDeadline, date: $cancellationDeadline)
                        optionalDateRow(title: String.localized("Set Reminder"), isOn: $hasReminder, date: $reminderDate)
                    }

                    documentRow

                    EntryFieldRow(icon: "note.text") {
                        TextField("Provider details — account number, terms…", text: $providerNotes, axis: .vertical)
                            .foregroundStyle(MonetaColor.textPrimary)
                            .lineLimit(3...6)
                    }

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    if entry.contractStatus != .cancelled {
                        Button(role: .destructive) {
                            showCancelConfirm = true
                        } label: {
                            Text("Cancel Contract")
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(MonetaColor.loss)
                    }
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(MonetaColor.canvas)
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Mark this contract as cancelled?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Mark as Cancelled", role: .destructive) {
                    store.cancelContract(entry)
                    showCancelledConfirmation = true
                }
            } message: {
                Text("It stays in your list with a Cancelled label — nothing is deleted.")
            }
            .fullScreenCover(isPresented: $showCancelledConfirmation) {
                ConfirmationMomentView(
                    icon: "checkmark.seal.fill", iconTint: MonetaColor.gain,
                    headline: String.localized("Contract cancelled"),
                    amount: entry.monthlyEquivalentAmount * 12, amountCaption: String.localized("a year"),
                    subtitle: String.localized("It stays in your list, marked Cancelled — nothing is deleted."),
                    buttonTitle: String.localized("Done")
                ) {
                    showCancelledConfirmation = false
                    dismiss()
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(onPick: handleImagePicked)
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(onPick: handleImagePicked)
            }
            .sheet(isPresented: $showFilePicker) {
                ContractFilePicker(onPick: handleFilePicked)
            }
            .fullScreenCover(isPresented: $showDocumentViewer) {
                ContractDocumentViewerSheet(entryID: entry.id)
            }
        }
    }

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeats")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonetaColor.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(RecurringFrequency.allCases) { option in
                    let isSelected = option == frequency
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.18)) { frequency = option }
                    } label: {
                        Text(option.title)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .foregroundStyle(isSelected ? MonetaColor.canvas : MonetaColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(isSelected ? MonetaColor.textPrimary : MonetaColor.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionalDateRow(title: String, isOn: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(spacing: 0) {
            Toggle(title, isOn: isOn.animation(.snappy(duration: 0.18)))
                .tint(MonetaColor.accent)
            if isOn.wrappedValue {
                DatePicker(title, selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .padding(.top, 8)
            }
        }
        .padding(14)
        .monetaCard(radius: MonetaMetrics.tileRadius)
    }

    private var documentRow: some View {
        Group {
            if hasDocument {
                Button {
                    showDocumentViewer = true
                } label: {
                    documentRowLabel(title: String.localized("Document Attached"), subtitle: String.localized("Tap to view"), showsCheckmark: true)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { showCamera = true } label: { Label("Scan with Camera", systemImage: "camera") }
                    Button { showPhotoPicker = true } label: { Label("Choose Photo", systemImage: "photo.on.rectangle") }
                    Button { showFilePicker = true } label: { Label("Choose File", systemImage: "folder") }
                    Button(role: .destructive) { removeDocument() } label: { Label("Remove Document", systemImage: "trash") }
                }
            } else {
                Menu {
                    Button { showCamera = true } label: { Label("Scan with Camera", systemImage: "camera") }
                    Button { showPhotoPicker = true } label: { Label("Choose Photo", systemImage: "photo.on.rectangle") }
                    Button { showFilePicker = true } label: { Label("Choose File", systemImage: "folder") }
                } label: {
                    documentRowLabel(title: String.localized("Upload Document"), subtitle: String.localized("Scan, photo, or an existing PDF"), showsCheckmark: false)
                }
            }
        }
    }

    private func documentRowLabel(title: String, subtitle: String, showsCheckmark: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "paperclip")
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            Spacer(minLength: 6)
            if showsCheckmark {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(MonetaColor.gain)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonetaColor.textTertiary)
        }
        .padding(14)
        .monetaCard(radius: MonetaMetrics.tileRadius)
    }

    private func handleImagePicked(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        Task {
            await ContractDocumentStore.shared.store(data, for: entry.id, fileExtension: "jpg")
            hasDocument = true
            store.setHasDocument(true, for: entry)
        }
    }

    private func handleFilePicked(_ data: Data, _ fileExtension: String) {
        Task {
            await ContractDocumentStore.shared.store(data, for: entry.id, fileExtension: fileExtension)
            hasDocument = true
            store.setHasDocument(true, for: entry)
        }
    }

    private func removeDocument() {
        Task { await ContractDocumentStore.shared.delete(for: entry.id) }
        hasDocument = false
        store.setHasDocument(false, for: entry)
    }

    private func save() {
        guard let amount else { return }
        store.updateContract(
            entry, name: name.trimmingCharacters(in: .whitespaces), amount: amount, frequency: frequency,
            providerName: providerName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : providerName.trimmingCharacters(in: .whitespaces),
            contractEndDate: hasEndDate ? contractEndDate : nil,
            cancellationDeadline: hasCancellationDeadline ? cancellationDeadline : nil,
            reminderDate: hasReminder ? reminderDate : nil,
            providerNotes: providerNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : providerNotes
        )
        Haptics.success()
        dismiss()
    }
}

// MARK: - File picker (existing PDF from Files)

private struct ContractFilePicker: UIViewControllerRepresentable {
    let onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ContractFilePicker
        init(_ parent: ContractFilePicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { return }
            parent.onPick(data, url.pathExtension.isEmpty ? "pdf" : url.pathExtension)
        }
    }
}

// MARK: - Document viewer

private struct ContractDocumentViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID

    @State private var data: Data?
    @State private var fileExtension = ""

    var body: some View {
        NavigationStack {
            Group {
                if let data {
                    if fileExtension.lowercased() == "pdf" {
                        ContractPDFView(data: data)
                    } else if let uiImage = UIImage(data: data) {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            if let document = await ContractDocumentStore.shared.document(for: entryID) {
                data = document.data
                fileExtension = document.fileExtension
            }
        }
    }
}

private struct ContractPDFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

#Preview {
    let entry = RecurringEntry(name: "Vodafone Internet", amount: 49.99, isIncome: false, frequency: .monthly, anchorDate: Date(), kind: .contract)
    Color.clear.sheet(isPresented: .constant(true)) {
        ContractDetailSheet(entry: entry).environmentObject(FinanceStore())
    }
}
