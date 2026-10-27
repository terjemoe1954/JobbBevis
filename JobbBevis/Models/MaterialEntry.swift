import Foundation
import SwiftData

enum MaterialUnit: String, CaseIterable, Identifiable {
    case pieces = "pcs"
    case millimeter = "mm"
    case centimeter = "cm"
    case meter = "m"
    case squareMeter = "m²"
    case cubicMeter = "m³"
    case liter = "l"
    case kilogram = "kg"
    case hour = "h"
    case package

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .pieces: "Pieces"
        case .millimeter: "Millimeter"
        case .centimeter: "Centimeter"
        case .meter: "Meter"
        case .squareMeter: "Square meter"
        case .cubicMeter: "Cubic meter"
        case .liter: "Liter"
        case .kilogram: "Kilogram"
        case .hour: "Hour"
        case .package: "Package"
        }
    }

    var abbreviation: LocalizedStringResource {
        switch self {
        case .pieces: "pcs"
        case .millimeter: "mm"
        case .centimeter: "cm"
        case .meter: "m"
        case .squareMeter: "m²"
        case .cubicMeter: "m³"
        case .liter: "l"
        case .kilogram: "kg"
        case .hour: "h"
        case .package: "pkg"
        }
    }
}

@Model
final class MaterialEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Decimal
    var unit: String
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var unitPrice: Decimal?
    var job: JobRecord

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Decimal,
        unit: String,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        job: JobRecord,
        unitPrice: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.unitPrice = unitPrice
        self.job = job
    }
}
