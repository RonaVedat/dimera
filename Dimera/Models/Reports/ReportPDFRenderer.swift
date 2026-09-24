import SwiftUI
import UIKit

/// Bridges SwiftUI report pages into a real, multi-page vector PDF —
/// `ImageRenderer` hands back a `CGContext` per page, drawn straight into
/// `UIGraphicsPDFRenderer`'s page context, so text stays genuine Core Text
/// output (selectable, crisp, small file size) rather than a rasterized
/// screenshot. This is Apple's own documented technique (WWDC22), not a
/// third-party PDF library.
enum ReportPDFRenderer {
    /// A4 at 72dpi — this app's design (and market) has been European-first
    /// throughout, so A4 is the default rather than US Letter.
    static let pageSize = CGSize(width: 595, height: 842)

    /// Renders each page view in order to one PDF, written to a fresh temp
    /// file. Temp, not `Application Support` — these are one-shot
    /// share-sheet exports, not a persisted report library.
    @MainActor
    static func render(pages: [AnyView]) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try? pdfRenderer.writePDF(to: url) { context in
            for page in pages {
                context.beginPage()
                // Forced light appearance: a shared/printed PDF must look
                // like a clean document regardless of the device's own
                // dark-mode setting — `MonetaColor`'s system-adaptive
                // tokens would otherwise render a black page in dark mode.
                //
                // Forced locale: `ImageRenderer` renders into an isolated
                // context that does NOT inherit `.environment(\.locale)`
                // from wherever the page value was constructed — it starts
                // from SwiftUI's own default (`Locale.autoupdatingCurrent`,
                // i.e. the device's system locale). Every plain `Text("…")`
                // literal in a report page would otherwise silently follow
                // the device's language instead of the user's chosen
                // in-app `AppLanguage`, even though `String.localized(...)`
                // calls elsewhere on the same page are unaffected (they
                // resolve their own bundle directly, independent of the
                // view environment).
                let imageRenderer = ImageRenderer(
                    content: page.frame(width: pageSize.width, height: pageSize.height)
                        .environment(\.colorScheme, .light)
                        .environment(\.locale, AppLanguage.current.locale)
                )
                // `UIGraphicsPDFRendererContext.cgContext` is a plain Core
                // Graphics context — native bottom-left origin, Y increasing
                // upward. `ImageRenderer`'s render closure draws assuming a
                // UIKit-style top-left origin, so without this flip every
                // page comes out mirrored top-to-bottom.
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageSize.height)
                cgContext.scaleBy(x: 1, y: -1)
                imageRenderer.render { _, renderFn in renderFn(cgContext) }
                cgContext.restoreGState()
            }
        }
        return url
    }
}
