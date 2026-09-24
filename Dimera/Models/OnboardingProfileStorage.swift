import Foundation

/// Persists the goal/profile choices made during onboarding so Settings can
/// show them back to the user. Plain UserDefaults rather than `@AppStorage`
/// — nothing needs live reactivity across two simultaneously-open screens,
/// since Settings is only reachable once onboarding has already finished.
enum OnboardingProfileStorage {
    private static let profileKey = "financialProfileRaw"
    private static let goalsKey = "financialGoalsRaw"

    static var selectedProfile: FinancialProfile? {
        get { FinancialProfile(rawValue: UserDefaults.standard.string(forKey: profileKey) ?? "") }
        set { UserDefaults.standard.set(newValue?.rawValue ?? "", forKey: profileKey) }
    }

    static var selectedGoals: Set<FinancialGoal> {
        get {
            let raw = UserDefaults.standard.string(forKey: goalsKey) ?? ""
            return Set(raw.split(separator: ",").compactMap { FinancialGoal(rawValue: String($0)) })
        }
        set { UserDefaults.standard.set(newValue.map(\.rawValue).joined(separator: ","), forKey: goalsKey) }
    }
}
