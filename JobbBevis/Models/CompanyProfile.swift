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
    var bankAccount: String?
    var vatRegisteredMarker: Bool?
    var businessRegisterMarker: Bool?
    var defaultHourlyRate: Decimal?
    var defaultDrivingRatePerKilometer: Decimal?
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
        bankAccount: String? = nil,
        isVATRegistered: Bool = false,
        isRegisteredInBusinessRegister: Bool = false,
        defaultHourlyRate: Decimal? = nil,
        defaultDrivingRatePerKilometer: Decimal? = nil,
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
        self.bankAccount = bankAccount
        self.vatRegisteredMarker = isVATRegistered ? true : nil
        self.businessRegisterMarker = isRegisteredInBusinessRegister ? true : nil
        self.defaultHourlyRate = defaultHourlyRate
        self.defaultDrivingRatePerKilometer = defaultDrivingRatePerKilometer
        self.logoRelativePath = logoRelativePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isVATRegistered: Bool {
        get { vatRegisteredMarker ?? false }
        set { vatRegisteredMarker = newValue ? true : nil }
    }

    var isRegisteredInBusinessRegister: Bool {
        get { businessRegisterMarker ?? false }
        set { businessRegisterMarker = newValue ? true : nil }
    }
}
