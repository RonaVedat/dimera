import SwiftUI

@main
struct DimeraApp: App {
    @StateObject private var store = FinanceStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedSnapshot") private var hasCompletedSnapshot = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.dark.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .dark
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingFlowView(isComplete: $hasCompletedOnboarding)
                } else if !hasCompletedSnapshot {
                    FinancialSnapshotView(onComplete: { hasCompletedSnapshot = true })
                } else {
                    RootTabView()
                }
            }
            .environmentObject(store)
            .environment(\.locale, appLanguage.locale)
            .preferredColorScheme(appearanceMode.colorScheme)
            .task {
                StoreManager.shared.start()
            }
            .onChange(of: scenePhase) { _, phase in
                // Family membership and sharing can change while Dimera is
                // in the background, and there's no server to hear about it.
                if phase == .active {
                    Task { await StoreManager.shared.refresh() }
                }
            }
        }
    }
}
