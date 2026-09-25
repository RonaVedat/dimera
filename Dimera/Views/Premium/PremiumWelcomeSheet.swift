import SwiftUI

/// Confirms Premium is active instead of a paywall silently vanishing
/// (visibility of system status). The family-member variant uses the HIG's
/// own suggested wording — "Your family subscription includes…" — and
/// answers the first question a shared finance subscription raises: can my
/// family see my money? (No.)
struct PremiumWelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let variant: PremiumWelcomeVariant

    private var headline: String {
        switch variant {
        case .individual: return String.localized("Premium is active")
        case .familyPurchaser: return String.localized("Premium Family is active")
        case .familyMember: return String.localized("Your family subscription includes…")
        }
    }

    private var message: String {
        switch variant {
        case .individual:
            return String.localized("Everything below is unlocked now.")
        case .familyPurchaser:
            return String.localized("Family members get Premium automatically when they open Dimera with their own Apple ID.")
        case .familyMember:
            return String.localized("Your data stays on this device. Your family can't see your finances.")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PremiumHeaderBadge()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(MonetaColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(MonetaColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PremiumFeatureList(includesFamily: variant == .familyPurchaser)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .background(MonetaColor.canvas)
            .safeAreaInset(edge: .bottom) {
                Button("Start exploring") { dismiss() }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .padding(.horizontal, MonetaMetrics.screenPadding)
                    .padding(.bottom, 16)
                    .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { Haptics.success() }
    }
}

#Preview {
    PremiumWelcomeSheet(variant: .familyMember)
}
