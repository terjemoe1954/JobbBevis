import Foundation
import SwiftData

@Model
final class WorkEntry {
    @Attribute(.unique) var id: UUID
    var workDate: Date
    var details: String
    var durationMinutes: Int
    var drivingKilometers: Decimal?
    var createdAt: Date
    var updatedAt: Date
    var job: JobRecord

    init(
        id: UUID = UUID(),
        workDate: Date,
        details: String,
        durationMinutes: Int,
        drivingKilometers: Decimal? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        job: JobRecord
    ) {
        self.id = id
        self.workDate = workDate
        self.details = details
        self.durationMinutes = durationMinutes
        self.drivingKilometers = drivingKilometers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.job = job
    }
}
