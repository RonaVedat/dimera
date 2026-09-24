import SwiftUI
import UIKit

/// A compact segmented control styled as a pill row. Kept custom (rather than
/// the system `.segmented` Picker) to match the low-chrome, card-free look
/// used throughout Home and Goals — but it behaves like any other Picker:
/// single selection, full accessibility, and haptic feedback on change.
struct PeriodPicker: View {
    @Binding var selection: ChartPeriod

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ChartPeriod.allCases) { period in
                let isSelected = period == selection
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.2)) {
                        selection = period
                    }
                } label: {
                    Text(period.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? MonetaColor.textPrimary : MonetaColor.textTertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background {
                            if isSelected {
                                Capsule().fill(MonetaColor.card)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .accessibilityElement(children: .contain)
    }
}
