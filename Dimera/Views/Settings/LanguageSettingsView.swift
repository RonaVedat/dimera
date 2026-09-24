import SwiftUI

/// A plain list, not a segmented picker — six languages don't fit a
/// segmented control, and this is the same "pick one, see a checkmark"
/// idiom iOS's own Settings → Language uses. Changing the selection takes
/// effect immediately (no relaunch), since `.environment(\.locale)` is set
/// once at the `DimeraApp` root from this same `@AppStorage` key.
struct LanguageSettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    var body: some View {
        List {
            Section {
                row(for: .system)
            } footer: {
                Text("Follows your device's own Language & Region setting.")
            }

            Section {
                ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                    row(for: language)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for language: AppLanguage) -> some View {
        Button {
            Haptics.selection()
            appLanguageRaw = language.rawValue
        } label: {
            HStack {
                Text(language.title)
                    .foregroundStyle(MonetaColor.textPrimary)
                Spacer()
                if appLanguage == language {
                    Image(systemName: "checkmark")
                        .foregroundStyle(MonetaColor.accent)
                }
            }
        }
        .accessibilityAddTraits(appLanguage == language ? [.isSelected] : [])
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
