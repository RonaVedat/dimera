import SwiftUI
import UIKit

/// The Trade Republic-style hero amount: one huge number, nothing else
/// competing with it. Shared by every entry form so the first thing the
/// user does is always the same gesture.
struct AmountEntryField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("€")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(MonetaColor.textSecondary)
            TextField("0", text: $text)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(MonetaColor.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .fixedSize()
                .focused(focused)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Amount in euros")
    }
}

/// Parses "12,50" and "12.50" alike — German keyboards produce commas.
func parseAmount(_ text: String) -> Decimal? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard let value = Decimal(string: normalized), value > 0 else { return nil }
    return value
}

/// One-tap category chips in a wrapping grid — no dropdown, no submenu.
struct CategoryChips: View {
    @Binding var selection: TransactionCategory
    /// Categories to leave out entirely — used by Add Budget to hide
    /// categories that already have one, since a budget is one-per-category.
    /// Empty by default, so every other call site is unaffected.
    var excluding: Set<TransactionCategory> = []

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TransactionCategory.allCases.filter { !excluding.contains($0) }) { category in
                let isSelected = category == selection
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.18)) { selection = category }
                } label: {
                    Label(category.title, systemImage: category.systemImage)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? MonetaColor.canvas : MonetaColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            isSelected ? MonetaColor.textPrimary : MonetaColor.card,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}

/// Icon + content row used for the secondary fields under the amount.
struct EntryFieldRow<Content: View>: View {
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)
                .frame(width: 20)
            content
        }
        .padding(14)
        .monetaCard(radius: MonetaMetrics.tileRadius)
    }
}

/// Full-width save button pinned under the form.
struct EntrySaveButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
        }
        .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}
