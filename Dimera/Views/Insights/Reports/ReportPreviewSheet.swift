import SwiftUI
import PDFKit

/// Generate → Preview → Share, in one sheet — deliberately the only three
/// steps. No page-size/orientation/margin/chart-toggle screen: the pages
/// are pre-built by the caller, this just renders them once and shows the
/// result exactly as it will be shared.
struct ReportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let pages: [AnyView]

    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let pdfURL {
                    PDFKitPreview(url: pdfURL)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(white: 0.93))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let pdfURL {
                        ShareLink(item: pdfURL, preview: SharePreview(title, image: Image(systemName: "doc.richtext"))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .task {
            if pdfURL == nil {
                pdfURL = ReportPDFRenderer.render(pages: pages)
            }
        }
    }
}

private struct PDFKitPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .init(white: 0.93, alpha: 1)
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
