import Foundation
import SwiftData

@Model
final class CompanyProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var organizationNumber: String
    var phone: String
    var email: String
    var address: String
    var logoRelativePath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        organizationNumber: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        logoRelativePath: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.organizationNumber = organizationNumber
        self.phone = phone
        self.email = email
        self.address = address
        self.logoRelativePath = logoRelativePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
