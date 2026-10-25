import Foundation
import SwiftData

enum JobStatus: String, CaseIterable, Identifiable {
    case planned
    case inProgress
    case completed

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .planned: "Planned"
        case .inProgress: "In progress"
        case .completed: "Completed"
        }
    }
}

@Model
final class JobRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var jobNumber: String
    var title: String
    var workAddress: String
    var details: String
    var plannedDate: Date
    var statusRawValue: String
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var sampleDataMarker: Bool?
    var customer: Customer
    @Relationship(deleteRule: .cascade, inverse: \JobPhoto.job)
    var photos: [JobPhoto]
    @Relationship(deleteRule: .cascade, inverse: \WorkEntry.job)
    var workEntries: [WorkEntry]
    @Relationship(deleteRule: .cascade, inverse: \MaterialEntry.job)
    var materialEntries: [MaterialEntry]

    var isSampleData: Bool {
        get { sampleDataMarker ?? false }
        set { sampleDataMarker = newValue }
    }

    var status: JobStatus {
        get { JobStatus(rawValue: statusRawValue) ?? .planned }
        set {
            statusRawValue = newValue.rawValue
            completedAt = newValue == .completed ? (completedAt ?? .now) : nil
            updatedAt = .now
        }
    }

    init(
        id: UUID = UUID(),
        jobNumber: String,
        title: String,
        customer: Customer,
        workAddress: String = "",
        details: String = "",
        plannedDate: Date = .now,
        status: JobStatus = .planned,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        photos: [JobPhoto] = [],
        workEntries: [WorkEntry] = [],
        materialEntries: [MaterialEntry] = [],
        isSampleData: Bool = false
    ) {
        self.id = id
        self.jobNumber = jobNumber
        self.title = title
        self.customer = customer
        self.workAddress = workAddress
        self.details = details
        self.plannedDate = plannedDate
        self.statusRawValue = status.rawValue
        self.completedAt = status == .completed ? (completedAt ?? .now) : nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sampleDataMarker = isSampleData ? true : nil
        self.photos = photos
        self.workEntries = workEntries
        self.materialEntries = materialEntries
    }
}

@Model
final class AppMetadata {
    @Attribute(.unique) var id: String
    var nextJobSequence: Int

    init(id: String = "main", nextJobSequence: Int = 1) {
        self.id = id
        self.nextJobSequence = nextJobSequence
    }
}
