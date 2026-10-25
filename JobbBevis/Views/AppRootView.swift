import SwiftUI

enum AppSection: Hashable {
    case jobs
    case customers
    case settings
}

struct AppRootView: View {
    @AppStorage(PreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(PreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @State private var selection: AppSection? = .jobs

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: AppSection.jobs) {
                    Label("Jobs", systemImage: "hammer")
                }
                NavigationLink(value: AppSection.customers) {
                    Label("Customers", systemImage: "person.2")
                }
                NavigationLink(value: AppSection.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .navigationTitle("JobbBevis")
        } detail: {
            switch selection ?? .jobs {
            case .jobs:
                JobsView()
            case .customers:
                CustomersView()
            case .settings:
                SettingsView()
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, language.locale ?? .autoupdatingCurrent)
    }
}
