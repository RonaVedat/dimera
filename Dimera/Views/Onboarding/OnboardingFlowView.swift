import SwiftUI

enum OnboardingStep: Equatable {
    case welcome, personalize, reminderPresets, freeEntry, value, bankConnection, complete
}

/// Splash plays once, outside the step stack entirely, then the video hero
/// (`.welcome`) opens the actual flow, absorbing what used to be a separate
/// Privacy screen as a trust strip in its own footer. `.personalize` and
/// `.reminderPresets` are linear. `.freeEntry` forks: "Connect bank now"
/// skips straight to the bank-connection trust screen, while "Create my
/// dashboard" goes to `.value` (a dashboard preview + Premium pitch) instead
/// — the two paths no longer converge on the same bank-connection screen,
/// since showing it to someone who explicitly didn't choose it was
/// redundant friction. Finishing always passes through a one-beat completion
/// celebration before handing off to the real app.
///
/// Navigation keeps a history stack rather than a bare current-step value so
/// Back always retraces the user's actual path through the fork, and screen
/// transitions push from the correct edge for the direction of travel.
struct OnboardingFlowView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isComplete: Bool

    @State private var showSplash = true
    @State private var path: [OnboardingStep] = [.welcome]
    @State private var isAdvancing = true
    @State private var selectedGoals: Set<FinancialGoal> = []
    @State private var selectedProfile: FinancialProfile?

    private var step: OnboardingStep { path.last ?? .welcome }

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(onFinished: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                })
                .transition(.opacity)
            } else {
                screen(for: step)
                    .id(step)
                    .transition(reduceMotion ? .opacity : .push(from: isAdvancing ? .trailing : .leading))
            }
        }
        .background(MonetaColor.canvas)
        .task {
            await store.load()
        }
    }

    @ViewBuilder
    private func screen(for step: OnboardingStep) -> some View {
        let progress = Double(stepIndex(step)) / 4
        let label = "Step \(stepIndex(step) + 1) of 5"
        let back: (() -> Void)? = path.count > 1 ? goBack : nil

        switch step {
        case .welcome:
            HeroWelcomeView(next: { go(to: .personalize) })
        case .personalize:
            PersonalizeStepView(
                selectedGoals: $selectedGoals, selectedProfile: $selectedProfile,
                next: { go(to: .reminderPresets) }, progress: progress, stepLabel: label, onBack: back
            )
        case .reminderPresets:
            SmartReminderPresetStepView(next: { go(to: .freeEntry) }, progress: progress, stepLabel: label, onBack: back)
        case .freeEntry:
            FreeEntryStepView(
                createDashboard: { go(to: .value) },
                connectBankNow: { go(to: .bankConnection) },
                progress: progress, stepLabel: label, onBack: back
            )
        case .value:
            ValueStepView(next: { go(to: .complete) }, progress: progress, stepLabel: label, onBack: back)
        case .bankConnection:
            BankConnectionStepView(finish: { go(to: .complete) }, progress: progress, stepLabel: label, onBack: back)
        case .complete:
            OnboardingCompleteView(onFinish: finish)
        }
    }

    private func go(to next: OnboardingStep) {
        isAdvancing = true
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.35)) {
            path.append(next)
        }
    }

    private func goBack() {
        guard path.count > 1 else { return }
        isAdvancing = false
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.35)) {
            _ = path.removeLast()
        }
    }

    private func finish() {
        OnboardingProfileStorage.selectedGoals = selectedGoals
        OnboardingProfileStorage.selectedProfile = selectedProfile
        isComplete = true
    }

    private func stepIndex(_ step: OnboardingStep) -> Int {
        switch step {
        case .welcome: return 0
        case .personalize: return 1
        case .reminderPresets: return 2
        case .freeEntry: return 3
        case .value, .bankConnection, .complete: return 4
        }
    }
}

#Preview {
    let store = FinanceStore()
    OnboardingFlowView(isComplete: .constant(false))
        .environmentObject(store)
        .task { await store.load() }
}
