import SwiftUI

enum AppTab: Hashable {
    case home, activity, insights, goals
}

struct RootTabView: View {
    @EnvironmentObject private var store: FinanceStore
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var selection: AppTab = .home

    private var isFirstLoad: Bool {
        store.isLoading && store.transactions.isEmpty && store.loadError == nil
    }

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                HomeView(selection: $selection)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(AppTab.home)

                ActivityView()
                    .tabItem { Label("Activity", systemImage: "list.bullet") }
                    .tag(AppTab.activity)

                InsightsView()
                    .tabItem { Label("Insights", systemImage: "sparkles") }
                    .tag(AppTab.insights)

                GoalsView()
                    .tabItem { Label("Goals", systemImage: "target") }
                    .tag(AppTab.goals)
            }
            .tint(MonetaColor.textPrimary)
            .opacity(isFirstLoad || store.loadError != nil ? 0 : 1)

            if isFirstLoad {
                ProgressView()
                    .tint(MonetaColor.textPrimary)
            } else if let error = store.loadError {
                LoadErrorView(message: error) {
                    Task { await store.load() }
                }
            }
        }
        .background(MonetaColor.canvas)
        .task {
            await store.load()
        }
        .sheet(item: welcomeBinding, onDismiss: storeManager.welcomeShown) { variant in
            PremiumWelcomeSheet(variant: variant)
        }
    }

    /// Premium changes that happen outside the paywall — a family member's
    /// first access, an approved Ask to Buy — still deserve a welcome.
    private var welcomeBinding: Binding<PremiumWelcomeVariant?> {
        Binding(
            get: { storeManager.pendingWelcome },
            set: { if $0 == nil { storeManager.welcomeShown() } }
        )
    }
}

private struct LoadErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(MonetaColor.textSecondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.canvas)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(MonetaColor.textPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
    }
}
