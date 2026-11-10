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
    @State private var usesPeriod = false
    @State private var fromDate = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var throughDate = Date.now
    @State private var excludedIDs = Set<UUID>()

    private var eligibleInvoices: [InvoiceRecord] {
        AccountingExportSelection.invoices(invoices, from: usesPeriod ? fromDate : nil, through: usesPeriod ? throughDate : nil)
    }
    private var selectedInvoices: [InvoiceRecord] { eligibleInvoices.filter { !excludedIDs.contains($0.id) } }
    private var summary: AccountingExportSummary? { try? AccountingExportSelection.summary(selectedInvoices) }
    private var invalidPeriod: Bool { usesPeriod && Calendar.current.startOfDay(for: fromDate) > Calendar.current.startOfDay(for: throughDate) }
    private var canExport: Bool { !invalidPeriod && !selectedInvoices.isEmpty && summary != nil }

    private func selection(for invoice: InvoiceRecord) -> Binding<Bool> {
        Binding(get: { !excludedIDs.contains(invoice.id) }, set: { included in
            if included { excludedIDs.remove(invoice.id) } else { excludedIDs.insert(invoice.id) }
        })
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Choose period") {
                    Toggle("Limit by invoice date", isOn: $usesPeriod)
                    if usesPeriod {
                        DatePicker("From date", selection: $fromDate, displayedComponents: .date)
                        DatePicker("Through date", selection: $throughDate, displayedComponents: .date)
                        if invalidPeriod { Text("The from date must not be later than the through date.").foregroundStyle(.red) }
                    }
                    Text("The period includes both dates and uses the invoice issue date. Invoices outside the period are not exported.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Choose invoices") {
                    Button("Select all in view") { excludedIDs.subtract(eligibleInvoices.map(\.id)) }
                        .disabled(eligibleInvoices.isEmpty)
                    Button("Deselect all in view") { excludedIDs.formUnion(eligibleInvoices.map(\.id)) }
                        .disabled(eligibleInvoices.isEmpty)
                    ForEach(eligibleInvoices) { invoice in
                        Toggle(isOn: selection(for: invoice)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Invoice \(invoice.invoiceNumber)").font(.headline)
                                Text(invoice.issuedAt, format: .dateTime.day().month().year())
                                if let snapshot = invoice.snapshot {
                                    Text(snapshot.customerName)
                                    Text(PriceEstimateCalculator.currency(snapshot.total, locale: locale))
                                } else {
                                    Text("The stored invoice could not be read.").foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    if eligibleInvoices.isEmpty && !invalidPeriod { Text("No ordinary invoices match this period.") }
                }
                Section("Check selection") {
                    LabeledContent("Invoices in view", value: "\(eligibleInvoices.count)")
                    if let summary {
                        LabeledContent("Selected invoices", value: "\(summary.invoices)")
                        LabeledContent("Invoice lines", value: "\(summary.lines)")
                        LabeledContent("Subtotal excluding VAT", value: PriceEstimateCalculator.currency(summary.subtotal, locale: locale))
                        LabeledContent("VAT", value: PriceEstimateCalculator.currency(summary.vat, locale: locale))
                        LabeledContent("Total", value: PriceEstimateCalculator.currency(summary.total, locale: locale)).font(.headline)
                    } else {
                        Text("A selected invoice could not be read. Deselect it or restore a valid copy before exporting.").foregroundStyle(.red)
                    }
                    Text("Exercise invoices are excluded from ordinary accounting export.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Export to accounting") {
                    Button("Export CSV file", systemImage: "square.and.arrow.up", action: prepareExport)
                        .disabled(!canExport)
                    Button("Accounting report (PDF)", systemImage: "doc.richtext", action: preparePDFReport)
                        .disabled(!canExport)

                    Text("The CSV file contains one row per invoice line with invoice, customer, amount, and VAT information. The receiving accounting system may require the columns to be mapped during import.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("CSV format") {
                    Text("One row per invoice line. Sum line_subtotal, line_vat and line_total for line amounts. invoice_subtotal, invoice_vat and invoice_total repeat on every line and must be counted only once per invoice_number.")
                        .font(.footnote)
                    Text("Export creates a file. It does not confirm import or bookkeeping in an accounting system.")
                        .font(.footnote).foregroundStyle(.secondary)
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
        guard canExport else { return }
        do {
            csvExportItem = AccountingCSVTransferItem(
                data: try AccountingCSVExportService().exportData(invoices: selectedInvoices)
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
        guard canExport else { return }
        do {
            pdfExportItem = AccountingPDFTransferItem(
                data: try AccountingReportPDFService().exportData(invoices: selectedInvoices, locale: locale)
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
