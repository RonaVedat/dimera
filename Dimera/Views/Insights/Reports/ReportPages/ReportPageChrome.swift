import SwiftUI

/// The one consistent frame every report page sits inside — title, period,
/// generation date, a footer wordmark — so all four report kinds read as
/// one coherent document rather than four different exports. Deliberately
/// spare: no page numbers, no configuration, matching the "very little
/// text, lots of breathing room" brief this whole feature is built around.
struct ReportPageChrome<Content: View>: View {
    let reportTitle: String
    let period: String
    /// An optional legal line appended below the usual footer — used only
    /// by the tax-export reports; every other report kind passes `nil` and
    /// is unaffected.
    var legalNote: String? = nil
    @ViewBuilder var content: Content

    private static var generatedDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return String.localized("Generated \(formatter.string(from: Date()))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(period)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ReportColor.accent)
                Text(reportTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(ReportColor.textPrimary)
                Text(Self.generatedDateLabel)
                    .font(.footnote)
                    .foregroundStyle(ReportColor.textSecondary)
            }
            .padding(.bottom, 20)

            content

            Spacer(minLength: 0)

            Divider().overlay(ReportColor.separator)
            HStack {
                Text("Dimera")
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("Financial clarity, every day.")
                    .font(.footnote)
            }
            .foregroundStyle(ReportColor.textTertiary)
            .padding(.top, 12)

            if let legalNote {
                Text(legalNote)
                    .font(.caption2)
                    .foregroundStyle(ReportColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(width: ReportPDFRenderer.pageSize.width, height: ReportPDFRenderer.pageSize.height, alignment: .topLeading)
        .background(ReportColor.background)
    }
}

/// Fixed, non-adaptive colors for report pages — a shared PDF always reads
/// as a clean white document, independent of `MonetaColor`'s system dark/
/// light tokens (which would otherwise vary with whoever's viewing it).
enum ReportColor {
    static let background = Color.white
    static let textPrimary = Color.black
    static let textSecondary = Color(white: 0.42)
    static let textTertiary = Color(white: 0.65)
    static let separator = Color(white: 0.88)
    static let gain = Color(red: 0.20, green: 0.60, blue: 0.35)
    static let loss = Color(red: 0.75, green: 0.25, blue: 0.25)
    static let warning = Color(red: 0.80, green: 0.45, blue: 0.05) // systemOrange, fixed for print
    static let accent = Color(red: 0.345, green: 0.337, blue: 0.839) // systemIndigo, fixed for print
    static let chartPalette: [Color] = [accent, Color(white: 0.25), Color(white: 0.55), gain, Color(white: 0.75), loss]
}
