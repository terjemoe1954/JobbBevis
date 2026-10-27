import Foundation
import SwiftData

@Model
final class Customer {
    var id: UUID
    var customerNumber: String?
    var name: String
    var contactPerson: String
    var phone: String
    var email: String
    var address: String
    var organizationNumber: String?
    var createdAt: Date
    var updatedAt: Date
    var sampleDataMarker: Bool?
    @Relationship(deleteRule: .deny, inverse: \JobRecord.customer)
    var jobs: [JobRecord]

    var isSampleData: Bool {
        get { sampleDataMarker ?? false }
        set { sampleDataMarker = newValue }
    }

    init(
        id: UUID = UUID(),
        customerNumber: String? = nil,
        name: String,
        contactPerson: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        organizationNumber: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        jobs: [JobRecord] = [],
        isSampleData: Bool = false
    ) {
        self.id = id
        self.customerNumber = customerNumber
        self.name = name
        self.contactPerson = contactPerson
        self.phone = phone
        self.email = email
        self.address = address
        self.organizationNumber = organizationNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sampleDataMarker = isSampleData ? true : nil
        self.jobs = jobs
    }
}
