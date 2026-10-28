import SwiftData
import SwiftUI

struct DirectoryReportsView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \Customer.name) private var customers: [Customer]
    @Query(sort: \Supplier.name) private var suppliers: [Supplier]
    @Query(sort: [SortDescriptor(\ProductCatalogItem.itemNumber), SortDescriptor(\ProductCatalogItem.name)])
    private var products: [ProductCatalogItem]
    @Query(sort: \JobRecord.jobNumber) private var jobs: [JobRecord]
    @State private var preview: DirectoryReportPreview?
    @State private var errorMessage: String?

    var body: some View {
        List {
            DirectoryReportRow(title: "Customer list", count: customers.count, icon: "person.2.fill") {
                generateCustomers()
            }
            DirectoryReportRow(title: "Supplier list", count: suppliers.count, icon: "truck.box.fill") {
                generateSuppliers()
            }
            DirectoryReportRow(title: "Product list", count: products.count, icon: "shippingbox.fill") {
                generateProducts()
            }
            DirectoryReportRow(title: "Job list", count: jobs.count, icon: "hammer.fill") {
                generateJobs()
            }
        }
        .appListAppearance()
        .navigationTitle("Reports")
        .sheet(item: $preview) { PDFPreviewView(pdfURL: $0.url) }
        .alert("Could not generate report", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func generateCustomers() {
        generate(
            title: String(localized: "Customer list"),
            headings: [String(localized: "Customer number"), String(localized: "Name"), String(localized: "Phone"), String(localized: "Email")],
            rows: customers.map { [$0.customerNumber ?? "", $0.name, $0.phone, $0.email] }
        )
    }

    private func generateSuppliers() {
        generate(
            title: String(localized: "Supplier list"),
            headings: [String(localized: "Supplier number"), String(localized: "Name"), String(localized: "Phone"), String(localized: "Email")],
            rows: suppliers.map { [$0.supplierNumber, $0.name, $0.phone, $0.email] }
        )
    }

    private func generateProducts() {
        generate(
            title: String(localized: "Product list"),
            headings: [String(localized: "Item number"), String(localized: "Name"), String(localized: "Supplier"), String(localized: "Unit price")],
            rows: products.map {
                [$0.itemNumber ?? "", $0.name, $0.supplierRecord?.name ?? $0.supplier,
                 PriceEstimateCalculator.currency($0.unitPrice, locale: locale)]
            }
        )
    }

    private func generateJobs() {
        generate(
            title: String(localized: "Job list"),
            headings: [String(localized: "Job number"), String(localized: "Title"), String(localized: "Customer"), String(localized: "Status")],
            rows: jobs.map { [$0.jobNumber, $0.title, $0.customer.name, String(localized: $0.status.title)] }
        )
    }

    private func generate(title: String, headings: [String], rows: [[String]]) {
        do {
            preview = DirectoryReportPreview(url: try DirectoryReportPDFService().generate(title: title, headings: headings, rows: rows))
        } catch {
            errorMessage = String(localized: "The report could not be generated. Try again.")
        }
    }
}

private struct DirectoryReportRow: View {
    let title: LocalizedStringResource
    let count: Int
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                LabeledContent { Text(count, format: .number) } label: { Text(title) }
            } icon: {
                Image(systemName: icon)
            }
        }
    }
}

private struct DirectoryReportPreview: Identifiable {
    let id = UUID()
    let url: URL
}
