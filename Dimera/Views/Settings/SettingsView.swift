import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isPremium") private var isPremium = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("hasCompletedSnapshot") private var hasCompletedSnapshot = true
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.dark.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var showPaywall = false
    @State private var receiptCount = 0
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @AppStorage(TaxDataExporter.lastNameKey) private var taxExportLastName = ""

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
                PaywallView()
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
        Section {
            HStack(spacing: 14) {
                Image(systemName: isPremium ? "sparkles" : "lock")
                    .font(.title3)
                    .foregroundStyle(MonetaColor.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isPremium ? "Dimera Premium" : "Free plan")
                        .font(.subheadline.weight(.semibold))
                    Text(isPremium ? "Insights and forecasting unlocked" : "Manual tracking and basic dashboard")
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                }

                Spacer()

                if !isPremium {
                    Button {
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

            if !isPremium {
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
        }
        .alert("Nothing to restore", isPresented: showRestoreMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
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
            if !isPremium {
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
            Toggle("Simulate Premium", isOn: $isPremium)
                .tint(MonetaColor.accent)
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
    #endif
}

#Preview {
    SettingsView().environmentObject(FinanceStore())
}
