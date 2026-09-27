import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isPremium") private var isPremium = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("hasCompletedSnapshot") private var hasCompletedSnapshot = true
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.dark.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showPaywall = false
    @State private var paywallAudience: PremiumAudience = .justMe
    @State private var showManageSubscriptions = false
    @State private var receiptCount = 0
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @AppStorage(TaxDataExporter.lastNameKey) private var taxExportLastName = ""
    @AppStorage("userFirstName") private var userFirstName = ""

    private var appearanceMode: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .dark },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    private let profile = OnboardingProfileStorage.selectedProfile
    private let goals = OnboardingProfileStorage.selectedGoals

    var body: some View {
        NavigationStack {
            List {
                yourNameSection

                premiumSection

                if profile != nil || !goals.isEmpty {
                    yourProfileSection
                }

                appearanceSection

                languageSection

                notificationsSection

                receiptsSection

                taxExportSection

                aboutSection

                #if DEBUG
                debugSection
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(initialAudience: paywallAudience)
            }
            .task {
                receiptCount = await ReceiptStore.shared.receiptCount
            }
        }
    }

    private var receiptsSection: some View {
        Section {
            LabeledContent(
                "Receipts",
                value: isPremium
                    ? String.localized("\(receiptCount) saved")
                    : String.localized("\(receiptCount) of 100 saved")
            )
        } footer: {
            Text("Photos are compressed and stored only on this device.")
        }
    }

    private var yourNameSection: some View {
        Section {
            TextField(String.localized("Your first name"), text: $userFirstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        } footer: {
            Text("Used for your greeting on Home — leave blank for a plain \"Good morning\".")
        }
    }

    private var taxExportSection: some View {
        Section {
            TextField(String.localized("Your name"), text: $taxExportLastName)
                .textContentType(.familyName)
        } header: {
            Text("Tax Export")
        } footer: {
            Text("Used only to name your tax export files — never shown anywhere else.")
        }
    }

    private var premiumSection: some View {
        let state = storeManager.state
        return Section {
            HStack(spacing: 14) {
                Image(systemName: state.isPremium ? "sparkles" : "lock")
                    .font(.title3)
                    .foregroundStyle(MonetaColor.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle)
                        .font(.subheadline.weight(.semibold))
                    ForEach(planDetails, id: \.self) { line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                }

                Spacer()

                if state.shouldOfferPurchase && storeManager.canMakePayments {
                    Button {
                        paywallAudience = .justMe
                        showPaywall = true
                    } label: {
                        Text("Upgrade")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MonetaColor.canvas)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(MonetaColor.textPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            if let notice = premiumNotice {
                Label(notice, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.warning)
            }

            if state.canManage || storeManager.renewal == .paymentProblem {
                Button("Manage subscription") {
                    showManageSubscriptions = true
                }
            }

            if state.canUpgradeToFamily && storeManager.familyPlanAvailable && storeManager.canMakePayments {
                Button("Upgrade to Family") {
                    paywallAudience = .family
                    showPaywall = true
                }
            }

            if state == .free {
                Button {
                    restore()
                } label: {
                    HStack {
                        Text("Restore Purchases")
                        if isRestoring {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring)
            }
        } footer: {
            if let footer = premiumFooter {
                Text(footer)
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions, groupID: storeManager.subscriptionGroupID)
        .alert("Nothing to restore", isPresented: showRestoreMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    private var planTitle: String {
        switch storeManager.state {
        case .free: return String.localized("Free plan")
        case .individual: return String.localized("Dimera Premium")
        case .familyPurchaser: return String.localized("Premium Family · Shared with your family")
        case .familyMember: return String.localized("Premium Family · Shared with you")
        case .otherShared: return String.localized("Dimera Premium · Included")
        }
    }

    private var planDetails: [String] {
        let renewalText = storeManager.renewal.flatMap { $0 == .paymentProblem ? nil : $0.displayText }
        switch storeManager.state {
        case .free:
            return [String.localized("Tracking, budgets, net worth and subscriptions")]
        case .individual(let plan):
            return [plan.title, renewalText].compactMap { $0 }
        case .familyPurchaser:
            return [renewalText].compactMap { $0 }
        case .familyMember:
            return [String.localized("Included in your family's subscription.")]
        case .otherShared:
            return []
        }
    }

    private var premiumNotice: String? {
        if storeManager.renewal == .paymentProblem {
            return RenewalSummary.paymentProblem.displayText
        }
        if case .familyMember(let alsoPays) = storeManager.state, alsoPays != nil {
            return String.localized("Your family plan already covers you. You can cancel your own subscription to avoid paying twice.")
        }
        return nil
    }

    private var premiumFooter: String? {
        switch storeManager.state {
        case .individual where storeManager.familyPlanAvailable && storeManager.canMakePayments:
            return String.localized("Upgrading to Family gives you a prorated refund for the rest of your current plan.")
        case .familyPurchaser:
            return String.localized("Everyone in your Family Sharing group gets Premium. If someone doesn't, check that Share with Family is on in Settings › Family › Subscriptions.")
        default:
            return nil
        }
    }

    private var showRestoreMessage: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            defer { isRestoring = false }
            try? await StoreManager.shared.restorePurchases()
            if !StoreManager.shared.state.isPremium {
                restoreMessage = String.localized("We didn't find an active Dimera Premium subscription for this Apple ID.")
            }
        }
    }

    private var yourProfileSection: some View {
        Section("Your profile") {
            if let profile {
                LabeledContent("I am", value: profile.title)
            }
            if !goals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goals")
                        .font(.subheadline)
                    ForEach(Array(goals), id: \.self) { goal in
                        Label(goal.title, systemImage: goal.systemImage)
                            .font(.footnote)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 4)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Dimera is designed dark-first. System follows your device's setting.")
        }
    }

    private var languageSection: some View {
        Section {
            NavigationLink {
                LanguageSettingsView()
            } label: {
                LabeledContent("Language", value: appLanguage.title)
            }
        } footer: {
            Text("System follows your device's own language setting.")
        }
    }

    private var notificationsSection: some View {
        Section {
            NavigationLink("Reminders") {
                RemindersSettingsView()
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Daily spending reviews, weekly digests, and renewal reminders.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0")
            VStack(alignment: .leading, spacing: 4) {
                Label("Your data stays on this device", systemImage: "lock.shield")
                    .font(.subheadline)
                Text("Dimera doesn't sell personal information, and manual transactions never leave your phone.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            .padding(.vertical, 2)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Picker("Simulate Premium", selection: debugPremiumOverride) {
                ForEach(DebugPremiumOption.allCases) { option in
                    Text(verbatim: option.label).tag(option)
                }
            }
            Button("Restart onboarding") {
                dismiss()
                FinancialSnapshotStorage.current = nil
                LedgerStorage.current = nil
                Task { await ReceiptStore.shared.deleteAll() }
                hasCompletedSnapshot = false
                hasCompletedOnboarding = false
            }
            .foregroundStyle(MonetaColor.loss)
        } header: {
            Text("Debug")
        } footer: {
            Text("Development-only controls — never shown in a release build.")
        }
    }

    private var debugPremiumOverride: Binding<DebugPremiumOption> {
        Binding(
            get: { DebugPremiumOption(state: storeManager.currentDebugOverride) },
            set: { storeManager.setDebugOverride($0.state) }
        )
    }
    #endif
}

private extension View {
    /// The group-scoped sheet opens straight to Dimera's subscription; the
    /// fallback covers the moment before products have loaded.
    @ViewBuilder
    func manageSubscriptionsSheet(isPresented: Binding<Bool>, groupID: String?) -> some View {
        if let groupID {
            manageSubscriptionsSheet(isPresented: isPresented, subscriptionGroupID: groupID)
        } else {
            manageSubscriptionsSheet(isPresented: isPresented)
        }
    }
}

#if DEBUG
private enum DebugPremiumOption: String, CaseIterable, Identifiable {
    case real, free, monthly, yearly, familyPurchaser, familyMember, familyMemberAlsoPays, otherShared

    var id: String { rawValue }

    var label: String {
        switch self {
        case .real: return "Real (StoreKit)"
        case .free: return "Free"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .familyPurchaser: return "Family purchaser"
        case .familyMember: return "Family member"
        case .familyMemberAlsoPays: return "Family member + own plan"
        case .otherShared: return "Organization"
        }
    }

    var state: PremiumState? {
        switch self {
        case .real: return nil
        case .free: return .free
        case .monthly: return .individual(.monthly)
        case .yearly: return .individual(.yearly)
        case .familyPurchaser: return .familyPurchaser
        case .familyMember: return .familyMember(alsoPays: nil)
        case .familyMemberAlsoPays: return .familyMember(alsoPays: .monthly)
        case .otherShared: return .otherShared
        }
    }

    init(state: PremiumState?) {
        self = Self.allCases.first { $0.state == state } ?? .real
    }
}
#endif

#Preview {
    SettingsView().environmentObject(FinanceStore())
}
