import Foundation
import SwiftData

enum ProjectMode: String, CaseIterable, Identifiable {
    case simpleJob
    case mainContract

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .simpleJob: "Simple job"
        case .mainContract: "Main contract"
        }
    }
}

enum ProjectPartyRole: String, CaseIterable, Identifiable {
    case mainContractor
    case subcontractor
    case materialSupplier
    case consultant
    case internalResource

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .mainContractor: "Main contractor"
        case .subcontractor: "Subcontractor"
        case .materialSupplier: "Material supplier"
        case .consultant: "Consultant"
        case .internalResource: "Internal resource"
        }
    }
}

enum WorkPackageStatus: String, CaseIterable, Identifiable {
    case planned
    case ready
    case inProgress
    case completed
    case onHold

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .planned: "Planned"
        case .ready: "Ready"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .onHold: "On hold"
        }
    }
}

@Model
final class ProjectTrade {
    @Attribute(.unique) var id: UUID
    var code: String
    var name: String
    var isInternal: Bool
    var plannedHours: Decimal?
    var createdAt: Date
    var updatedAt: Date
    var job: JobRecord

    init(
        id: UUID = UUID(),
        code: String,
        name: String,
        isInternal: Bool = false,
        plannedHours: Decimal? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        job: JobRecord
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.isInternal = isInternal
        self.plannedHours = plannedHours
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.job = job
    }
}

@Model
final class ProjectParty {
    @Attribute(.unique) var id: UUID
    var roleRawValue: String
    var contactPerson: String
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var job: JobRecord
    var supplier: Supplier?
    var trade: ProjectTrade?

    var role: ProjectPartyRole {
        get { ProjectPartyRole(rawValue: roleRawValue) ?? .subcontractor }
        set { roleRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: ProjectPartyRole,
        contactPerson: String = "",
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        job: JobRecord,
        supplier: Supplier? = nil,
        trade: ProjectTrade? = nil
    ) {
        self.id = id
        self.roleRawValue = role.rawValue
        self.contactPerson = contactPerson
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.job = job
        self.supplier = supplier
        self.trade = trade
    }
}

@Model
final class WorkPackage {
    @Attribute(.unique) var id: UUID
    var packageNumber: String
    var title: String
    var details: String
    var statusRawValue: String
    var plannedStart: Date?
    var plannedEnd: Date?
    var progressPercent: Int
    var budgetExcludingVAT: Decimal?
    var plannedHours: Decimal?
    var materialBudgetIncludingVAT: Decimal?
    var laborBudgetIncludingVAT: Decimal?
    var createdAt: Date
    var updatedAt: Date
    var job: JobRecord
    var trade: ProjectTrade?
    var responsibleParty: ProjectParty?

    var status: WorkPackageStatus {
        get { WorkPackageStatus(rawValue: statusRawValue) ?? .planned }
        set { statusRawValue = newValue.rawValue }
    }

    var totalBudgetIncludingVAT: Decimal {
        max(0, materialBudgetIncludingVAT ?? 0) + max(0, laborBudgetIncludingVAT ?? 0)
    }

    var totalBudgetExcludingVAT: Decimal {
        max(0, budgetExcludingVAT ?? 0)
    }

    init(
        id: UUID = UUID(),
        packageNumber: String,
        title: String,
        details: String = "",
        status: WorkPackageStatus = .planned,
        plannedStart: Date? = nil,
        plannedEnd: Date? = nil,
        progressPercent: Int = 0,
        budgetExcludingVAT: Decimal? = nil,
        plannedHours: Decimal? = nil,
        materialBudgetIncludingVAT: Decimal? = nil,
        laborBudgetIncludingVAT: Decimal? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        job: JobRecord,
        trade: ProjectTrade? = nil,
        responsibleParty: ProjectParty? = nil
    ) {
        self.id = id
        self.packageNumber = packageNumber
        self.title = title
        self.details = details
        self.statusRawValue = status.rawValue
        self.plannedStart = plannedStart
        self.plannedEnd = plannedEnd
        self.progressPercent = min(100, max(0, progressPercent))
        self.budgetExcludingVAT = budgetExcludingVAT
        self.plannedHours = plannedHours
        self.materialBudgetIncludingVAT = materialBudgetIncludingVAT
        self.laborBudgetIncludingVAT = laborBudgetIncludingVAT
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.job = job
        self.trade = trade
        self.responsibleParty = responsibleParty
    }
}
