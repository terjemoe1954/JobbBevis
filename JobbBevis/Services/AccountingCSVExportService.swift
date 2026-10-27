import Foundation

enum AccountingCSVExportError: LocalizedError {
    case noInvoices
    case invalidInvoice(String)

    var errorDescription: String? {
        switch self {
        case .noInvoices:
            String(localized: "There are no approved invoices to export.")
        case .invalidInvoice(let number):
            String(localized: "Invoice \(number) could not be read and was not exported.")
        }
    }
}

struct AccountingCSVExportService {
    private let header = [
        "invoice_number", "invoice_date", "due_date", "currency", "job_number", "job_title",
        "seller_name", "seller_organization_number", "customer_name", "customer_organization_number",
        "customer_address", "delivery_date", "delivery_address", "line_description", "quantity", "unit",
        "unit_price_excluding_vat", "vat_rate_percent", "line_subtotal", "line_vat", "line_total",
        "invoice_subtotal", "invoice_vat", "invoice_total"
    ]

    func exportData(invoices: [InvoiceRecord]) throws -> Data {
        guard !invoices.isEmpty else { throw AccountingCSVExportError.noInvoices }

        var rows = [header]
        for invoice in invoices.sorted(by: { $0.issuedAt < $1.issuedAt }) {
            guard let snapshot = invoice.snapshot else {
                throw AccountingCSVExportError.invalidInvoice(invoice.invoiceNumber)
            }
            for line in snapshot.lines {
                rows.append([
                    invoice.invoiceNumber,
                    isoDate(invoice.issuedAt),
                    isoDate(invoice.dueDate),
                    "NOK",
                    invoice.jobNumber,
                    snapshot.jobTitle,
                    snapshot.sellerName,
                    snapshot.sellerOrganizationNumber,
                    snapshot.customerName,
                    snapshot.customerOrganizationNumber,
                    snapshot.customerAddress,
                    isoDate(snapshot.deliveryDate),
                    snapshot.deliveryAddress,
                    line.description,
                    decimal(line.quantity),
                    line.unit,
                    decimal(line.unitPrice),
                    decimal(line.vatRatePercent),
                    decimal(line.subtotal),
                    decimal(line.vat),
                    decimal(line.total),
                    decimal(snapshot.subtotal),
                    decimal(snapshot.vat),
                    decimal(snapshot.total)
                ])
            }
        }

        let csv = rows.map { $0.map(escaped).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        guard let data = ("\u{FEFF}" + csv).data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return data
    }

    private func escaped(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func decimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func isoDate(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }
}
