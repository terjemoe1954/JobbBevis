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
    var estimatedHours: Decimal?
    var hourlyRate: Decimal?
    var drivingKilometers: Decimal?
    var drivingRatePerKilometer: Decimal?
    var vatRatePercent: Decimal?
    var invoiceDraftMarker: Bool?
    var invoiceDraftDueDate: Date?
    var archivedAt: Date?
    var customer: Customer
    @Relationship(deleteRule: .cascade, inverse: \JobPhoto.job)
    var photos: [JobPhoto]
    @Relationship(deleteRule: .cascade, inverse: \WorkEntry.job)
    var workEntries: [WorkEntry]
    @Relationship(deleteRule: .cascade, inverse: \MaterialEntry.job)
    var materialEntries: [MaterialEntry]
    @Relationship(deleteRule: .cascade, inverse: \PurchaseItem.job)
    var purchaseItems: [PurchaseItem]

    var isSampleData: Bool {
        get { sampleDataMarker ?? false }
        set { sampleDataMarker = newValue }
    }

    var hasInvoiceDraft: Bool {
        get { invoiceDraftMarker ?? false }
        set {
            invoiceDraftMarker = newValue ? true : nil
            if !newValue {
                invoiceDraftDueDate = nil
            }
            updatedAt = .now
        }
    }

    var isArchived: Bool {
        archivedAt != nil
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
        purchaseItems: [PurchaseItem] = [],
        isSampleData: Bool = false,
        estimatedHours: Decimal? = nil,
        hourlyRate: Decimal? = nil,
        drivingKilometers: Decimal? = nil,
        drivingRatePerKilometer: Decimal? = nil,
        vatRatePercent: Decimal? = nil,
        hasInvoiceDraft: Bool = false,
        invoiceDraftDueDate: Date? = nil,
        archivedAt: Date? = nil
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
        self.estimatedHours = estimatedHours
        self.hourlyRate = hourlyRate
        self.drivingKilometers = drivingKilometers
        self.drivingRatePerKilometer = drivingRatePerKilometer
        self.vatRatePercent = vatRatePercent
        self.invoiceDraftMarker = hasInvoiceDraft ? true : nil
        self.invoiceDraftDueDate = hasInvoiceDraft ? invoiceDraftDueDate : nil
        self.archivedAt = archivedAt
        self.photos = photos
        self.workEntries = workEntries
        self.materialEntries = materialEntries
        self.purchaseItems = purchaseItems
    }
}

@Model
final class AppMetadata {
    @Attribute(.unique) var id: String
    var nextJobSequence: Int
    var nextInvoiceSequence: Int?
    var nextCreditNoteSequence: Int?

    init(
        id: String = "main",
        nextJobSequence: Int = 1,
        nextInvoiceSequence: Int = 1,
        nextCreditNoteSequence: Int = 1
    ) {
        self.id = id
        self.nextJobSequence = nextJobSequence
        self.nextInvoiceSequence = nextInvoiceSequence
        self.nextCreditNoteSequence = nextCreditNoteSequence
    }
}
