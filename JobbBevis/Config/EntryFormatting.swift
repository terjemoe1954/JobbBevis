import Foundation

enum EntryFormatting {
    static func duration(hours: Int, minutes: Int) -> String {
        duration(totalMinutes: max(0, hours * 60 + minutes))
    }

    static func duration(totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return String(localized: "\(minutes) min")
        }
        if minutes == 0 {
            return String(localized: "\(hours) h")
        }
        return String(localized: "\(hours) h \(minutes) min")
    }

    static func parseDecimal(_ text: String, locale: Locale) -> Decimal? {
        try? Decimal(
            text.trimmingCharacters(in: .whitespacesAndNewlines),
            format: Decimal.FormatStyle(locale: locale)
        )
    }

    static func formatDecimal(_ value: Decimal, locale: Locale) -> String {
        value.formatted(Decimal.FormatStyle(locale: locale))
    }
}
