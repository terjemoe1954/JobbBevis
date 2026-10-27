import Foundation
import SwiftData

@Model
final class Supplier {
    @Attribute(.unique) var id: UUID
    var supplierNumber: String
    var name: String
    var contactPerson: String
    var phone: String
    var email: String
    var address: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ProductCatalogItem.supplierRecord)
    var products: [ProductCatalogItem]

    init(
        id: UUID = UUID(),
        supplierNumber: String,
        name: String,
        contactPerson: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        products: [ProductCatalogItem] = []
    ) {
        self.id = id
        self.supplierNumber = supplierNumber
        self.name = name
        self.contactPerson = contactPerson
        self.phone = phone
        self.email = email
        self.address = address
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.products = products
    }
}
