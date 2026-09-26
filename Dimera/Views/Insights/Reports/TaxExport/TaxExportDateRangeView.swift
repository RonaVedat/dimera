import SwiftUI

enum TaxExportDestination {
    case consolidatedStatement
    case rawData(TaxExportFormat)
}

/// Tier 2 — shared by both Tier-1 branches. Pre-fills the fiscal year the
/// device's own region actually uses (`FiscalYear.defaultRange()`), freely
/// adjustable via two plain date pickers — no other configuration.
struct TaxExportDateRangeView: View {
    @EnvironmentObject private var store: FinanceStore
    let destination: TaxExportDestination

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var format: TaxExportFormat
    @State private var showResult = false

    init(destination: TaxExportDestination) {
        self.destination = destination
        let defaultRange = FiscalYear.defaultRange()
        _startDate = State(initialValue: defaultRange.start)
        _endDate = State(initialValue: defaultRange.end)
        if case .rawData(let initialFormat) = destination {
            _format = State(initialValue: initialFormat)
        } else {
            _format = State(initialValue: .csv)
        }
    }

    /// Normalized so start always precedes end, regardless of how the two
    /// independent date pickers were dragged.
    private var range: FiscalYear.Range {
        startDate <= endDate
            ? FiscalYear.Range(start: startDate, end: endDate)
            : FiscalYear.Range(start: endDate, end: startDate)
    }

    var body: some View {
        Form {
            if case .rawData = destination {
                Section {
                    Picker("Format", selection: $format) {
                        ForEach(TaxExportFormat.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(format.subtitle)
                }
            }

            Section {
                DatePicker(String.localized("Start"), selection: $startDate, in: ...Date(), displayedComponents: .date)
                DatePicker(String.localized("End"), selection: $endDate, in: ...Date(), displayedComponents: .date)
            } header: {
                Text("Date range")
            }

            Section {
                Button {
                    Haptics.selection()
                    showResult = true
                } label: {
                    Text("Generate")
                        .frame(maxWidth: .infinity)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.canvas)
                }
                .listRowBackground(MonetaColor.textPrimary)
            } footer: {
                Text(TaxExportChoiceView.legalDisclaimer)
                    .font(.caption)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(MonetaColor.canvas)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showResult) {
            resultSheet
        }
    }

    private var navigationTitle: String {
        switch destination {
        case .consolidatedStatement: return String.localized("Consolidated Statement")
        case .rawData: return String.localized("Tax Prep Data")
        }
    }

    @ViewBuilder
    private var resultSheet: some View {
        switch destination {
        case .consolidatedStatement:
            let filtered = TaxDataExporter.transactions(from: store.transactions, in: range)
            let income = filtered.filter(\.isIncome).reduce(Decimal(0)) { $0 + $1.amount }
            let expenses = filtered.filter { !$0.isIncome }.reduce(Decimal(0)) { $0 + $1.amount }
            ReportPreviewSheet(
                title: String.localized("Annual Consolidated Report"),
                pages: [AnyView(AnnualConsolidatedReportPage(
                    range: range, income: income, expenses: expenses,
                    categories: TaxDataExporter.categoryBreakdown(for: filtered),
                    legalNote: TaxExportChoiceView.legalDisclaimer
                ))]
            )
        case .rawData:
            TaxExportRawResultView(format: format, range: range, transactions: store.transactions)
        }
    }
}

/// Tier 3 for the raw-data path — no PDF-style preview makes sense for a
/// CSV/OFX, so this generates the file and instantly presents the native
/// share sheet, exactly as asked (`UIActivityViewController`, not a
/// SwiftUI `ShareLink` tap-through) with the file already named
/// `LastName_Dimera_TaxData_2025.csv`.
private struct TaxExportRawResultView: View {
    @Environment(\.dismiss) private var dismiss
    let format: TaxExportFormat
    let range: FiscalYear.Range
    let transactions: [Transaction]

    @State private var fileURL: URL?
    @State private var deductibleTotal: Decimal = 0
    @State private var showConfirmation = false

    var body: some View {
        Group {
            if showConfirmation {
                ConfirmationMomentView(
                    icon: "doc.text.fill", iconTint: MonetaColor.accent,
                    headline: String.localized("Export ready"),
                    amount: deductibleTotal, amountCaption: String.localized("potentially deductible"),
                    subtitle: String.localized("Review the numbers, then share when you're ready."),
                    buttonTitle: String.localized("Share")
                ) {
                    showConfirmation = false
                }
            } else if let fileURL {
                ActivitySharePresenter(url: fileURL) { dismiss() }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.clear)
        .task {
            let filtered = TaxDataExporter.transactions(from: transactions, in: range)
            let content = format == .csv ? TaxDataExporter.csv(for: filtered) : TaxDataExporter.ofx(for: filtered)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(TaxDataExporter.filename(format: format, range: range))
            try? content.write(to: url, atomically: true, encoding: .utf8)
            deductibleTotal = TaxRadarScanner.scan(filtered).reduce(Decimal(0)) { $0 + $1.amount }
            fileURL = url
            showConfirmation = true
        }
    }
}

private struct ActivitySharePresenter: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard uiViewController.presentedViewController == nil else { return }
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityController.completionWithItemsHandler = { _, _, _, _ in onDismiss() }
        DispatchQueue.main.async {
            uiViewController.present(activityController, animated: true)
        }
    }
}
