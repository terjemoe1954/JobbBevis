import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AccountingCSVTransferItem: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { item in
            item.data
        }
    }
}

struct AccountingPDFTransferItem: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { item in
            item.data
        }
    }
}

struct AccountingTransferView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \InvoiceRecord.issuedAt, order: .reverse) private var invoices: [InvoiceRecord]
    @State private var csvExportItem: AccountingCSVTransferItem?
    @State private var pdfExportItem: AccountingPDFTransferItem?
    @State private var isExportingCSV = false
    @State private var isExportingPDF = false
    @State private var message: AccountingExportMessage?

    var body: some View {
        NavigationStack {
            List {
                Section("Export to accounting") {
                    Button("Export CSV file", systemImage: "square.and.arrow.up", action: prepareExport)
                        .disabled(invoices.isEmpty)
                    Button("Accounting report (PDF)", systemImage: "doc.richtext", action: preparePDFReport)
                        .disabled(invoices.isEmpty)

                    Text("The CSV file contains one row per invoice line with invoice, customer, amount, and VAT information. The receiving accounting system may require the columns to be mapped during import.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Ready for transfer") {
                    LabeledContent("Approved invoices", value: "\(invoices.count)")
                }
            }
            .navigationTitle("Export to accounting")
            .fileExporter(
                isPresented: $isExportingCSV,
                item: csvExportItem,
                contentTypes: [.commaSeparatedText],
                defaultFilename: csvFilename
            ) { result in
                switch result {
                case .success:
                    message = AccountingExportMessage(
                        title: String(localized: "Export completed"),
                        text: String(localized: "The accounting CSV file was exported successfully.")
                    )
                case .failure(let error):
                    message = AccountingExportMessage(
                        title: String(localized: "Could not export accounting file"),
                        text: error.localizedDescription
                    )
                }
            }
            .fileExporter(
                isPresented: $isExportingPDF,
                item: pdfExportItem,
                contentTypes: [.pdf],
                defaultFilename: pdfFilename
            ) { result in
                switch result {
                case .success:
                    message = AccountingExportMessage(
                        title: String(localized: "Export completed"),
                        text: String(localized: "The accounting report was exported successfully.")
                    )
                case .failure(let error):
                    message = AccountingExportMessage(
                        title: String(localized: "Could not export accounting report"),
                        text: error.localizedDescription
                    )
                }
            }
            .alert(item: $message) { message in
                Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var csvFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "JobbBevis-Regnskap-\(date)"
    }

    private var pdfFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "JobbBevis-Regnskapsrapport-\(date)"
    }

    private func prepareExport() {
        do {
            csvExportItem = AccountingCSVTransferItem(
                data: try AccountingCSVExportService().exportData(invoices: invoices)
            )
            isExportingCSV = true
        } catch {
            message = AccountingExportMessage(
                title: String(localized: "Could not export accounting file"),
                text: error.localizedDescription
            )
        }
    }

    private func preparePDFReport() {
        do {
            pdfExportItem = AccountingPDFTransferItem(
                data: try AccountingReportPDFService().exportData(invoices: invoices, locale: locale)
            )
            isExportingPDF = true
        } catch {
            message = AccountingExportMessage(
                title: String(localized: "Could not export accounting report"),
                text: error.localizedDescription
            )
        }
    }
}

private struct AccountingExportMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}
