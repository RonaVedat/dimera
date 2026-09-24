import SwiftUI

/// The circular merchant/subscription initial badge, or an income arrow.
struct IconBadge: View {
    enum Style {
        case initial(String)
        case income
    }

    let style: Style
    var size: CGFloat = 42

    var body: some View {
        Circle()
            .fill(background)
            .frame(width: size, height: size)
            .overlay {
                switch style {
                case .initial(let letter):
                    Text(letter)
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(MonetaColor.textPrimary)
                case .income:
                    Image(systemName: "arrow.down")
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(MonetaColor.gain)
                }
            }
    }

    private var background: Color {
        switch style {
        case .initial: return MonetaColor.cardElevated
        case .income: return MonetaColor.gain.opacity(0.15)
        }
    }
}
