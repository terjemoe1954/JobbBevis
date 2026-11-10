import Foundation

struct AccountingExportSummary {
    let invoices: Int
    let lines: Int
    let subtotal: Decimal
    let vat: Decimal
    let total: Decimal
}

enum AccountingExportSelection {
    /// Whole calendar days, inclusive at both ends. The next-day boundary also
    /// handles daylight-saving days without assuming that every day is 24 hours.
    static func invoices(_ records: [InvoiceRecord], from: Date? = nil, through: Date? = nil, excluding: Set<UUID> = [], calendar: Calendar = .current) -> [InvoiceRecord] {
        let start = from.map { calendar.startOfDay(for: $0) }
        let last = through.map { calendar.startOfDay(for: $0) }
        if let start, let last, start > last { return [] }
        let end = last.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
        var seen = Set<UUID>()
        return records.filter { record in
            guard !record.isExercise, !excluding.contains(record.id), seen.insert(record.id).inserted else { return false }
            return (start.map { record.issuedAt >= $0 } ?? true) && (end.map { record.issuedAt < $0 } ?? true)
        }.sorted {
            if $0.issuedAt != $1.issuedAt { return $0.issuedAt > $1.issuedAt }
            return $0.invoiceNumber < $1.invoiceNumber
        }
    }

    /// Invoice totals are counted once per invoice, not once per CSV line.
    static func summary(_ records: [InvoiceRecord]) throws -> AccountingExportSummary {
        let selected = invoices(records)
        var lines = 0
        var subtotal: Decimal = 0
        var vat: Decimal = 0
        var total: Decimal = 0
        for record in selected {
            guard let snapshot = record.snapshot else { throw AccountingCSVExportError.invalidInvoice(record.invoiceNumber) }
            lines += snapshot.lines.count
            subtotal += snapshot.subtotal
            vat += snapshot.vat
            total += snapshot.total
        }
        return AccountingExportSummary(invoices: selected.count, lines: lines, subtotal: subtotal, vat: vat, total: total)
    }
}
