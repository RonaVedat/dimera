import SwiftUI

enum AppTab: Hashable {
    case home, activity, insights, goals
}

struct RootTabView: View {
    @EnvironmentObject private var store: FinanceStore
    @ObservedObject private var storeManager = StoreManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: AppTab = .home

    private var isFirstLoad: Bool {
        store.isLoading && store.transactions.isEmpty && store.loadError == nil
    }

    var body: some View {
        ZStack {
            // Driven by size class, not device idiom — this is what
            // actually changes across iPad Split View/Slide Over, and what
            // keeps this one hierarchy instead of a separate iPad screen.
            // `selection` lives above this switch, so it survives a resize
            // between shells intact.
            Group {
                if horizontalSizeClass == .regular {
                    sidebarShell
                } else {
                    tabShell
                }
            }
            .opacity(isFirstLoad || store.loadError != nil ? 0 : 1)

            if isFirstLoad {
                HomeSkeletonView()
                    .transition(.opacity)
            } else if let error = store.loadError {
                LoadErrorView(message: error) {
                    Task { await store.load() }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isFirstLoad)
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

    /// Compact width — iPhone, or iPad in Slide Over/a narrow Split View.
    private var tabShell: some View {
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
    }

    /// Regular width — iPad, full screen or a wide Split View. Same 4
    /// destinations and the same `selection`, just presented as a sidebar
    /// instead of a tab bar (HIG: "consider taking advantage of larger
    /// spaces to switch from a tab bar to a sidebar").
    private var sidebarShell: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                Label("Home", systemImage: "house.fill").tag(AppTab.home)
                Label("Activity", systemImage: "list.bullet").tag(AppTab.activity)
                Label("Insights", systemImage: "sparkles").tag(AppTab.insights)
                Label("Goals", systemImage: "target").tag(AppTab.goals)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dimera")
        } detail: {
            // Each destination caps its own content width internally
            // (`.adaptiveContentWidth()`), not here — a `NavigationStack`'s
            // own root content resists being sized by a `.frame`/`HStack`
            // wrapper from an ancestor like this one.
            destination(for: selection)
        }
        .tint(MonetaColor.textPrimary)
    }

    /// `List(selection:)` on iOS only takes an optional binding (single,
    /// non-optional selection is macOS-only) — bridges to the same
    /// non-optional `selection` the tab shell uses, ignoring a deselect to
    /// `nil` so the sidebar always keeps one row current.
    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { selection },
            set: { if let newValue = $0 { selection = newValue } }
        )
    }

    @ViewBuilder
    private func destination(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(selection: $selection)
        case .activity: ActivityView()
        case .insights: InsightsView()
        case .goals: GoalsView()
        }
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
