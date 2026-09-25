import Foundation

/// External links the App Store requires on every subscription sign-up
/// screen (HIG "Making signup effortless": Terms of Service and Privacy
/// Policy).
enum AppLinks {
    /// Apple's standard EULA — valid as Terms of Use unless Dimera ships its
    /// own custom EULA in App Store Connect.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Required before App Store submission. Left `nil` until Dimera's
    /// privacy policy is published; the paywall hides the link meanwhile.
    static let privacyPolicy: URL? = nil
}
