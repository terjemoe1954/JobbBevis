import SwiftData
import SwiftUI

enum AppSection: Hashable {
    case jobs
    case customers
    case invoices
    case accounting
    case products
    case suppliers
    case settings
}

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
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
                NavigationLink(value: AppSection.invoices) {
                    Label("Invoices and approval", systemImage: "doc.text")
                }
                NavigationLink(value: AppSection.accounting) {
                    Label("Transfer to accounting", systemImage: "arrow.right.arrow.left")
                }
                NavigationLink(value: AppSection.products) {
                    Label("Product catalog", systemImage: "shippingbox")
                }
                NavigationLink(value: AppSection.suppliers) {
                    Label("Suppliers", systemImage: "truck.box")
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
            case .invoices:
                InvoicesView()
            case .accounting:
                AccountingTransferView()
            case .products:
                NavigationStack { ProductCatalogView() }
            case .suppliers:
                NavigationStack { SuppliersView() }
            case .settings:
                SettingsView()
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, language.locale ?? .autoupdatingCurrent)
        .task {
            try? DataMigrationService.migrateLegacyCatalogData(in: modelContext)
        }
    }
}
