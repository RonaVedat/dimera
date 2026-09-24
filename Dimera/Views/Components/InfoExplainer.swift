import SwiftUI

/// A small "why am I seeing this" affordance for real, computed insight
/// content — users trust an insight more when they can see the plain-
/// language reasoning behind it. The explanation text passed in is always
/// built from the same real numbers already shown on screen, never
/// separately invented copy.
struct InfoExplainer: View {
    let explanation: String
    @State private var showExplanation = false

    var body: some View {
        Button {
            showExplanation = true
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonetaColor.textTertiary)
        .popover(isPresented: $showExplanation, arrowEdge: .top) {
            Text(explanation)
                .font(.footnote)
                .foregroundStyle(MonetaColor.textPrimary)
                .padding(14)
                .frame(maxWidth: 260)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Why am I seeing this")
        .accessibilityHint(explanation)
    }
}
