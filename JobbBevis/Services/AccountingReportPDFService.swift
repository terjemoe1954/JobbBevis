import Foundation
import UIKit

struct AccountingReportPDFService {
    func exportData(invoices: [InvoiceRecord], locale: Locale) throws -> Data {
        guard !invoices.isEmpty else { throw AccountingCSVExportError.noInvoices }

        let records = try invoices.sorted(by: { $0.issuedAt < $1.issuedAt }).map { invoice in
            guard let snapshot = invoice.snapshot else {
                throw AccountingCSVExportError.invalidInvoice(invoice.invoiceNumber)
            }
            return (invoice, snapshot)
        }

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 36
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let money: (Decimal) -> String = { PriceEstimateCalculator.currency($0, locale: locale) }
        let localized: (String.LocalizationValue) -> String = {
            String(localized: LocalizedStringResource($0, locale: locale))
        }

        return renderer.pdfData { context in
            var y: CGFloat = 0

            func draw(
                _ value: String,
                x: CGFloat,
                width: CGFloat,
                font: UIFont,
                alignment: NSTextAlignment = .left,
                color: UIColor = .black
            ) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = alignment
                paragraph.lineBreakMode = .byTruncatingTail
                (value as NSString).draw(
                    in: CGRect(x: x, y: y, width: width, height: 18),
                    withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
                )
            }

            func beginPage() {
                context.beginPage()
                y = margin
                draw(localized("Accounting report"), x: margin, width: 300, font: .boldSystemFont(ofSize: 22))
                y += 29
                draw(records[0].1.sellerName, x: margin, width: 330, font: .boldSystemFont(ofSize: 11))
                draw(
                    localized("Generated") + ": " + Date.now.formatted(.dateTime.day().month().year().locale(locale)),
                    x: 375,
                    width: 184,
                    font: .systemFont(ofSize: 9),
                    alignment: .right,
                    color: .darkGray
                )
                y += 25
                draw(localized("Invoice no."), x: margin, width: 66, font: .boldSystemFont(ofSize: 8))
                draw(localized("Date"), x: 105, width: 55, font: .boldSystemFont(ofSize: 8))
                draw(localized("Customer"), x: 165, width: 160, font: .boldSystemFont(ofSize: 8))
                draw(localized("Excl. VAT"), x: 330, width: 75, font: .boldSystemFont(ofSize: 8), alignment: .right)
                draw(localized("VAT"), x: 410, width: 65, font: .boldSystemFont(ofSize: 8), alignment: .right)
                draw(localized("Total"), x: 480, width: 79, font: .boldSystemFont(ofSize: 8), alignment: .right)
                y += 16
                context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
                context.cgContext.move(to: CGPoint(x: margin, y: y))
                context.cgContext.addLine(to: CGPoint(x: page.width - margin, y: y))
                context.cgContext.strokePath()
                y += 7
            }

            beginPage()
            var subtotal: Decimal = 0
            var vat: Decimal = 0
            var total: Decimal = 0

            for (invoice, snapshot) in records {
                if y > page.height - 80 { beginPage() }
                draw(invoice.invoiceNumber, x: margin, width: 66, font: .systemFont(ofSize: 8))
                draw(
                    invoice.issuedAt.formatted(.dateTime.day().month().year().locale(locale)),
                    x: 105,
                    width: 55,
                    font: .systemFont(ofSize: 8)
                )
                draw(snapshot.customerName, x: 165, width: 160, font: .systemFont(ofSize: 8))
                draw(money(snapshot.subtotal), x: 330, width: 75, font: .systemFont(ofSize: 8), alignment: .right)
                draw(money(snapshot.vat), x: 410, width: 65, font: .systemFont(ofSize: 8), alignment: .right)
                draw(money(snapshot.total), x: 480, width: 79, font: .systemFont(ofSize: 8), alignment: .right)
                subtotal += snapshot.subtotal
                vat += snapshot.vat
                total += snapshot.total
                y += 17
            }

            y += 5
            context.cgContext.setStrokeColor(UIColor.darkGray.cgColor)
            context.cgContext.move(to: CGPoint(x: 330, y: y))
            context.cgContext.addLine(to: CGPoint(x: page.width - margin, y: y))
            context.cgContext.strokePath()
            y += 7
            draw(localized("Totals"), x: 165, width: 160, font: .boldSystemFont(ofSize: 9))
            draw(money(subtotal), x: 330, width: 75, font: .boldSystemFont(ofSize: 9), alignment: .right)
            draw(money(vat), x: 410, width: 65, font: .boldSystemFont(ofSize: 9), alignment: .right)
            draw(money(total), x: 480, width: 79, font: .boldSystemFont(ofSize: 9), alignment: .right)
        }
    }
}
