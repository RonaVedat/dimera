import SwiftUI

/// Wraps a Premium-only feature: free users see a blurred, non-interactive
/// preview of the real content behind a frosted lock card — Trade Republic's
/// own soft-paywall pattern — with a single tap through to `PaywallView`.
/// Premium users see `content` untouched.
struct PremiumGate<Content: View>: View {
    @AppStorage("isPremium") private var isPremium = false
    @State private var showPaywall = false

    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        if isPremium {
            content
        } else {
            ZStack {
                content
                    .blur(radius: 12)
                    .overlay(MonetaColor.canvas.opacity(0.4))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                lockCard
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var lockCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(MonetaColor.accent)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(MonetaColor.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                showPaywall = true
            } label: {
                Text("Unlock with Premium")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.canvas)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(MonetaColor.textPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
