import SwiftUI
import UIKit

struct SelectableCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? MonetaColor.canvas : MonetaColor.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? MonetaColor.accent : MonetaColor.cardElevated, in: Circle())
                    .scaleEffect(isSelected ? 1.08 : 1)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? MonetaColor.accent : MonetaColor.textTertiary)
                    .scaleEffect(isSelected ? 1.1 : 1)
            }
            .padding(15)
            .background(MonetaColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? MonetaColor.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(SpringPressStyle())
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// A tactile press-down-and-bounce-back, so picking a card feels like a
/// physical tap rather than a flat state toggle.
private struct SpringPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
