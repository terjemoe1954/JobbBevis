import Foundation

struct PriceEstimate: Equatable {
    let labor: Decimal
    let materials: Decimal
    let driving: Decimal
    let subtotal: Decimal
    let vat: Decimal
    let total: Decimal
}

enum PriceEstimateCalculator {
    static func estimate(for job: JobRecord) -> PriceEstimate {
        let labor = positive(job.estimatedHours) * positive(job.hourlyRate)
        let materials = job.materialEntries.reduce(Decimal.zero) { partial, entry in
            partial + entry.quantity * positive(entry.unitPrice)
        }
        let driving = positive(job.drivingKilometers) * positive(job.drivingRatePerKilometer)
        let subtotal = labor + materials + driving
        let vatRate = positive(job.vatRatePercent)
        let vat = subtotal * vatRate / 100

        return PriceEstimate(
            labor: labor,
            materials: materials,
            driving: driving,
            subtotal: subtotal,
            vat: vat,
            total: subtotal + vat
        )
    }

    static func currency(_ value: Decimal, locale: Locale) -> String {
        value.formatted(
            .currency(code: "NOK")
                .locale(locale)
                .precision(.fractionLength(2))
        )
    }

    private static func positive(_ value: Decimal?) -> Decimal {
        guard let value, value > 0 else { return 0 }
        return value
    }
}
