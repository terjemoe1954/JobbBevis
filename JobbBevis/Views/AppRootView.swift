import SwiftData
import SwiftUI

enum AppSection: Hashable {
    case jobs
    case customers
    case invoices
    case accounting
    case products
    case suppliers
    case reports
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
                    SidebarLabel(title: "Jobs", systemImage: "hammer.fill", color: .orange)
                }
                NavigationLink(value: AppSection.customers) {
                    SidebarLabel(title: "Customers", systemImage: "person.2.fill", color: .blue)
                }
                NavigationLink(value: AppSection.invoices) {
                    SidebarLabel(title: "Invoices and approval", systemImage: "doc.text.fill", color: .indigo)
                }
                NavigationLink(value: AppSection.accounting) {
                    SidebarLabel(title: "Export to accounting", systemImage: "chart.bar.doc.horizontal.fill", color: .green)
                }
                NavigationLink(value: AppSection.products) {
                    SidebarLabel(title: "Product catalog", systemImage: "shippingbox.fill", color: .purple)
                }
                NavigationLink(value: AppSection.suppliers) {
                    SidebarLabel(title: "Suppliers", systemImage: "truck.box.fill", color: .teal)
                }
                NavigationLink(value: AppSection.reports) {
                    SidebarLabel(title: "Reports", systemImage: "doc.text.magnifyingglass", color: .mint)
                }
                NavigationLink(value: AppSection.settings) {
                    SidebarLabel(title: "Settings", systemImage: "gearshape.fill", color: .gray)
                }
            }
            .appListAppearance()
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
            case .reports:
                NavigationStack { DirectoryReportsView() }
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

private struct SidebarLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 11) {
            FeatureIcon(systemImage: systemImage, color: color)
            Text(title)
        }
        .padding(.vertical, 3)
    }
}
