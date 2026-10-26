import Foundation
import SwiftData

struct SalesDocumentLine: Codable, Equatable, Identifiable {
    let id: UUID
    let description: String
    let quantity: Decimal
    let unit: String
    let unitPrice: Decimal
    let vatRatePercent: Decimal

    var subtotal: Decimal { quantity * unitPrice }
    var vat: Decimal { subtotal * vatRatePercent / 100 }
    var total: Decimal { subtotal + vat }
}

struct SalesDocumentSnapshot: Codable, Equatable {
    let sellerName: String
    let sellerOrganizationNumber: String
    let sellerAddress: String
    let sellerPhone: String
    let sellerEmail: String
    let sellerBankAccount: String
    let sellerIsVATRegistered: Bool
    let sellerIsRegisteredInBusinessRegister: Bool
    let customerName: String
    let customerOrganizationNumber: String
    let customerAddress: String
    let jobNumber: String
    let jobTitle: String
    let deliveryDate: Date
    let deliveryAddress: String
    let lines: [SalesDocumentLine]

    var subtotal: Decimal { lines.reduce(0) { $0 + $1.subtotal } }
    var vat: Decimal { lines.reduce(0) { $0 + $1.vat } }
    var total: Decimal { subtotal + vat }
}

@Model
final class InvoiceRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var invoiceNumber: String
    var jobID: UUID
    var jobNumber: String
    var issuedAt: Date
    var dueDate: Date
    var snapshotData: Data

    init(
        id: UUID = UUID(),
        invoiceNumber: String,
        jobID: UUID,
        jobNumber: String,
        issuedAt: Date,
        dueDate: Date,
        snapshotData: Data
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.jobID = jobID
        self.jobNumber = jobNumber
        self.issuedAt = issuedAt
        self.dueDate = dueDate
        self.snapshotData = snapshotData
    }

    var snapshot: SalesDocumentSnapshot? {
        try? JSONDecoder().decode(SalesDocumentSnapshot.self, from: snapshotData)
    }
}

@Model
final class CreditNoteRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var creditNoteNumber: String
    @Attribute(.unique) var originalInvoiceID: UUID
    var originalInvoiceNumber: String
    var jobNumber: String
    var issuedAt: Date
    var snapshotData: Data

    init(
        id: UUID = UUID(),
        creditNoteNumber: String,
        originalInvoiceID: UUID,
        originalInvoiceNumber: String,
        jobNumber: String,
        issuedAt: Date,
        snapshotData: Data
    ) {
        self.id = id
        self.creditNoteNumber = creditNoteNumber
        self.originalInvoiceID = originalInvoiceID
        self.originalInvoiceNumber = originalInvoiceNumber
        self.jobNumber = jobNumber
        self.issuedAt = issuedAt
        self.snapshotData = snapshotData
    }

    var snapshot: SalesDocumentSnapshot? {
        try? JSONDecoder().decode(SalesDocumentSnapshot.self, from: snapshotData)
    }
}
