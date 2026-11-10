import Foundation
import SwiftData
import UIKit

enum SalesDocumentError: LocalizedError {
    case missingCompanyInformation
    case missingBankAccount
    case missingCustomerInformation
    case missingVATRate
    case emptyDocument
    case invoiceAlreadyIssued
    case invalidOrganizationNumber
    case invalidBankAccount
    case datesNeedReview
    case acceptedBidAlreadyRecorded
    case creditNoteAlreadyIssued

    var errorDescription: String? {
        switch self {
        case .missingCompanyInformation:
            String(localized: "Complete the company name, organization number, and address in Settings first.")
        case .missingBankAccount:
            String(localized: "Add the company's bank account in Settings first.")
        case .missingCustomerInformation:
            String(localized: "Add the customer's name and address or organization number first.")
        case .missingVATRate:
            String(localized: "Enter a VAT rate for the job, or turn off VAT registration in Settings.")
        case .emptyDocument:
            String(localized: "Add priced registered work, materials, or driving before creating the document.")
        case .invoiceAlreadyIssued:
            String(localized: "This job already has an approved invoice. Open it as an invoice copy instead.")
        case .invalidOrganizationNumber:
            String(localized: "The organization number is not valid. Check it in Settings.")
        case .invalidBankAccount:
            String(localized: "The bank account number is not valid. Check it in Settings.")
        case .datesNeedReview:
            String(localized: "Review the date warnings before issuing the invoice.")
        case .acceptedBidAlreadyRecorded:
            String(localized: "An accepted bid is already recorded for this job.")
        case .creditNoteAlreadyIssued:
            String(localized: "This invoice has already been fully credited.")
        }
    }
}

@MainActor
enum SalesDocumentService {
    enum Basis {
        case estimate
        case registered
    }

    static func snapshot(
        job: JobRecord,
        company: CompanyProfile,
        basis: Basis = .registered,
        locale: Locale = .autoupdatingCurrent
    ) throws -> SalesDocumentSnapshot {
        func localized(_ resource: String.LocalizationValue) -> String {
            String(localized: LocalizedStringResource(resource, locale: locale))
        }
        let companyName = company.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let organizationNumber = company.organizationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let companyAddress = company.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !companyName.isEmpty, !organizationNumber.isEmpty, !companyAddress.isEmpty else {
            throw SalesDocumentError.missingCompanyInformation
        }
        guard !NumberValidationPreference.isEnabled
                || NorwegianNumberValidator.organizationNumberDigits(from: organizationNumber) != nil else {
            throw SalesDocumentError.invalidOrganizationNumber
        }
        let customerAddress = job.customer.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let customerOrganizationNumber = (job.customer.organizationNumber ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if NumberValidationPreference.isEnabled,
           !customerOrganizationNumber.isEmpty,
           NorwegianNumberValidator.organizationNumberDigits(from: customerOrganizationNumber) == nil {
            throw SalesDocumentError.invalidOrganizationNumber
        }
        guard !job.customer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !customerAddress.isEmpty || !customerOrganizationNumber.isEmpty else {
            throw SalesDocumentError.missingCustomerInformation
        }
        let vatRate: Decimal
        if company.isVATRegistered {
            guard let configuredRate = job.vatRatePercent else { throw SalesDocumentError.missingVATRate }
            vatRate = configuredRate
        } else {
            vatRate = 0
        }

        var lines: [SalesDocumentLine] = []
        let hours = basis == .estimate
            ? max(0, job.estimatedHours ?? 0)
            : PriceEstimateCalculator.registeredHours(for: job)
        if let rate = job.hourlyRate, hours > 0, rate >= 0 {
            lines.append(SalesDocumentLine(
                id: UUID(), description: localized("Work"), quantity: hours,
                unit: localized("hours"), unitPrice: rate, vatRatePercent: vatRate
            ))
        }
        if basis == .estimate {
            for item in job.purchaseItems.sorted(by: { $0.itemName.localizedStandardCompare($1.itemName) == .orderedAscending }) {
                guard item.quantity > 0, item.unitPrice >= 0 else { continue }
                lines.append(SalesDocumentLine(
                    id: UUID(), description: item.itemName, quantity: item.quantity,
                    unit: item.unit, unitPrice: item.unitPrice, vatRatePercent: vatRate, itemNumber: item.itemNumber
                ))
            }
        } else {
            struct GroupKey: Hashable {
                let sourceID: UUID
                let itemNumber: String?
                let name: String
                let unit: String
                let price: Decimal
                let vat: Decimal
            }
            var groups: [GroupKey: Int] = [:]
            for material in job.materialEntries.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
                guard let price = material.unitPrice, material.quantity > 0, price >= 0 else { continue }
                let sourceID = material.sourcePurchaseItemID ?? job.purchaseItems.first(where: { $0.transferredMaterialID == material.id })?.id
                let key = sourceID.map { GroupKey(sourceID: $0, itemNumber: material.itemNumber, name: material.name, unit: material.unit, price: price, vat: vatRate) }
                if job.combinesInvoiceLines, let key, let index = groups[key] {
                    let existing = lines[index]
                    lines[index] = SalesDocumentLine(
                        id: existing.id, description: existing.description,
                        quantity: existing.quantity + material.quantity, unit: existing.unit,
                        unitPrice: existing.unitPrice, vatRatePercent: existing.vatRatePercent,
                        itemNumber: existing.itemNumber,
                        sourceMaterialIDs: (existing.sourceMaterialIDs ?? []) + [material.id]
                    )
                } else {
                    if job.combinesInvoiceLines, let key { groups[key] = lines.count }
                    lines.append(SalesDocumentLine(
                        id: UUID(), description: material.name, quantity: material.quantity,
                        unit: material.unit, unitPrice: price, vatRatePercent: vatRate,
                        itemNumber: material.itemNumber, sourceMaterialIDs: [material.id]
                    ))
                }
            }
        }
        let kilometers = basis == .estimate
            ? max(0, job.drivingKilometers ?? 0)
            : PriceEstimateCalculator.registeredKilometers(for: job)
        if let rate = job.drivingRatePerKilometer, kilometers > 0, rate >= 0 {
            lines.append(SalesDocumentLine(
                id: UUID(), description: localized("Driving"), quantity: kilometers,
                unit: "km", unitPrice: rate, vatRatePercent: vatRate
            ))
        }
        guard !lines.isEmpty, lines.contains(where: { $0.total > 0 }) else {
            throw SalesDocumentError.emptyDocument
        }
        return SalesDocumentSnapshot(
            sellerName: companyName,
            sellerOrganizationNumber: organizationNumber,
            sellerAddress: companyAddress,
            sellerPhone: company.phone,
            sellerEmail: company.email,
            sellerBankAccount: company.bankAccount?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            sellerIsVATRegistered: company.isVATRegistered,
            sellerIsRegisteredInBusinessRegister: company.isRegisteredInBusinessRegister,
            customerName: job.customer.name,
            customerOrganizationNumber: customerOrganizationNumber,
            customerAddress: customerAddress,
            jobNumber: job.jobNumber,
            jobTitle: job.title,
            deliveryDate: job.completedAt ?? job.plannedDate,
            deliveryAddress: job.workAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? customerAddress
                : job.workAddress,
            lines: lines,
            exerciseMode: job.isExercise ? true : nil
        )
    }

    static func recordAcceptedBid(_ snapshot: SalesDocumentSnapshot, for job: JobRecord, at date: Date = .now, in context: ModelContext) throws {
        guard job.acceptedBidSnapshotData == nil else { throw SalesDocumentError.acceptedBidAlreadyRecorded }
        let data = try JSONEncoder().encode(snapshot)
        job.acceptedBidSnapshotData = data
        job.acceptedBidAt = date
        job.updatedAt = .now
        do { try context.save() } catch { context.rollback(); throw error }
    }

    static func nextSequence(after numbers: Set<String>, exercise: Bool) -> Int {
        numbers.filter { $0.hasPrefix("TEST-") == exercise }.compactMap {
            $0.split(separator: "-").last.flatMap { Int($0) }
        }.max().map { $0 + 1 } ?? 1
    }

    static func issueInvoice(
        job: JobRecord,
        company: CompanyProfile,
        dueDate: Date,
        datesAcknowledged: Bool = false,
        locale: Locale = .autoupdatingCurrent,
        in context: ModelContext
    ) throws -> InvoiceRecord {
        let jobID = job.id
        var existingInvoiceDescriptor = FetchDescriptor<InvoiceRecord>(
            predicate: #Predicate { $0.jobID == jobID }
        )
        existingInvoiceDescriptor.fetchLimit = 1
        guard try context.fetch(existingInvoiceDescriptor).isEmpty else {
            throw SalesDocumentError.invoiceAlreadyIssued
        }
        guard datesAcknowledged || JobDateValidation.issues(for: job, dueDate: dueDate, checksDelivery: true).isEmpty else {
            throw SalesDocumentError.datesNeedReview
        }
        let bankAccount = (company.bankAccount ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard job.isExercise || !bankAccount.isEmpty else {
            throw SalesDocumentError.missingBankAccount
        }
        guard job.isExercise || !NumberValidationPreference.isEnabled
                || NorwegianNumberValidator.bankAccountDigits(from: bankAccount) != nil else {
            throw SalesDocumentError.invalidBankAccount
        }
        let snapshot = try snapshot(job: job, company: company, locale: locale)
        var descriptor = FetchDescriptor<AppMetadata>(predicate: #Predicate { $0.id == "main" })
        descriptor.fetchLimit = 1
        let existingMetadata = try context.fetch(descriptor).first
        let metadata = existingMetadata ?? AppMetadata()
        if existingMetadata == nil { context.insert(metadata) }
        let sequence = job.isExercise ? (metadata.nextExerciseInvoiceSequence ?? 1) : (metadata.nextInvoiceSequence ?? 1)
        let year = Calendar.current.component(.year, from: .now)
        let number = (job.isExercise ? "TEST-" : "") + "\(year)-\(String(format: "%05d", sequence))"
        let data = try JSONEncoder().encode(snapshot)
        let invoice = InvoiceRecord(
            invoiceNumber: number,
            jobID: job.id,
            jobNumber: job.jobNumber,
            issuedAt: .now,
            dueDate: dueDate,
            snapshotData: data
        )
        context.insert(invoice)
        if job.isExercise { metadata.nextExerciseInvoiceSequence = sequence + 1 }
        else { metadata.nextInvoiceSequence = sequence + 1 }
        job.hasInvoiceDraft = false
        do {
            try context.save()
            return invoice
        } catch {
            context.rollback()
            throw error
        }
    }

    static func issueCreditNote(
        for invoice: InvoiceRecord,
        in context: ModelContext
    ) throws -> CreditNoteRecord {
        let invoiceID = invoice.id
        var existingDescriptor = FetchDescriptor<CreditNoteRecord>(
            predicate: #Predicate { $0.originalInvoiceID == invoiceID }
        )
        existingDescriptor.fetchLimit = 1
        guard try context.fetch(existingDescriptor).isEmpty else {
            throw SalesDocumentError.creditNoteAlreadyIssued
        }
        guard invoice.snapshot != nil else {
            throw SalesDocumentError.emptyDocument
        }

        var metadataDescriptor = FetchDescriptor<AppMetadata>(predicate: #Predicate { $0.id == "main" })
        metadataDescriptor.fetchLimit = 1
        let existingMetadata = try context.fetch(metadataDescriptor).first
        let metadata = existingMetadata ?? AppMetadata()
        if existingMetadata == nil { context.insert(metadata) }
        let sequence = invoice.isExercise ? (metadata.nextExerciseCreditNoteSequence ?? 1) : (metadata.nextCreditNoteSequence ?? 1)
        let year = Calendar.current.component(.year, from: .now)
        let number = (invoice.isExercise ? "TEST-" : "") + "KN-\(year)-\(String(format: "%05d", sequence))"
        let creditNote = CreditNoteRecord(
            creditNoteNumber: number,
            originalInvoiceID: invoice.id,
            originalInvoiceNumber: invoice.invoiceNumber,
            jobNumber: invoice.jobNumber,
            issuedAt: .now,
            snapshotData: invoice.snapshotData
        )
        context.insert(creditNote)
        if invoice.isExercise { metadata.nextExerciseCreditNoteSequence = sequence + 1 }
        else { metadata.nextCreditNoteSequence = sequence + 1 }
        do {
            try context.save()
            return creditNote
        } catch {
            context.rollback()
            throw error
        }
    }
}

struct SalesDocumentPDFService {
    enum Kind {
        case bid
        case acceptedBid(acceptedAt: Date)
        case orderConfirmation
        case invoiceDraft(dueDate: Date)
        case invoice(number: String, issuedAt: Date, dueDate: Date, isCopy: Bool)
        case creditNote(number: String, issuedAt: Date, originalInvoiceNumber: String)
    }

    func generate(snapshot: SalesDocumentSnapshot, kind: Kind, locale: Locale) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 44
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = try outputURL(snapshot: snapshot, kind: kind)
        try renderer.writePDF(to: url) { context in
            var y = margin
            func beginPage() {
                context.beginPage()
                y = margin
                if snapshot.exerciseMode == true {
                    let notice = String(localized: LocalizedStringResource("EXERCISE - DO NOT PAY", locale: locale))
                    (notice as NSString).draw(in: CGRect(x: margin, y: y, width: page.width - margin * 2, height: 24), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 13), .foregroundColor: UIColor.systemRed])
                    y += 30
                }
            }
            beginPage()
            func text(_ value: String, font: UIFont, color: UIColor = .black, gap: CGFloat = 5) {
                let rect = CGRect(x: margin, y: y, width: page.width - margin * 2, height: 100)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let size = (value as NSString).boundingRect(
                    with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes, context: nil
                ).size
                (value as NSString).draw(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(size.height)), withAttributes: attributes)
                y += ceil(size.height) + gap
            }
            func money(_ value: Decimal) -> String { PriceEstimateCalculator.currency(value, locale: locale) }
            func localized(_ resource: String.LocalizationValue) -> String {
                String(localized: LocalizedStringResource(resource, locale: locale))
            }
            func localizedUnit(_ unit: MaterialUnit) -> String {
                switch unit {
                case .pieces: localized("pcs")
                case .millimeter: "mm"
                case .centimeter: "cm"
                case .meter: "m"
                case .squareMeter: "m²"
                case .cubicMeter: "m³"
                case .liter: "l"
                case .kilogram: "kg"
                case .hour: localized("h")
                case .package: localized("pkg")
                case .bucket: localized("spann")
                case .box: localized("eske")
                case .set: localized("sett")
                case .roll: localized("rull")
                }
            }
            let title: String
            switch kind {
            case .bid: title = localized("Bid")
            case .acceptedBid: title = localized("Accepted bid")
            case .orderConfirmation: title = localized("Order confirmation")
            case .invoiceDraft: title = localized("Invoice draft")
            case let .invoice(_, _, _, isCopy):
                title = isCopy ? localized("Invoice copy") : localized("Invoice")
            case .creditNote:
                title = localized("Credit note")
            }
            text(title, font: .boldSystemFont(ofSize: 26), gap: 14)
            if case .invoiceDraft = kind {
                text(localized("DRAFT - Not issued. No invoice number assigned."), font: .boldSystemFont(ofSize: 11), color: .darkGray, gap: 12)
            }
            text(snapshot.sellerName, font: .boldSystemFont(ofSize: 13))
            var organization = localized("Org. no.") + ": " + snapshot.sellerOrganizationNumber
            if snapshot.sellerIsVATRegistered { organization += " MVA" }
            if snapshot.sellerIsRegisteredInBusinessRegister { organization += " · " + localized("Register of Business Enterprises") }
            text(organization, font: .systemFont(ofSize: 9), color: .darkGray)
            text(snapshot.sellerAddress, font: .systemFont(ofSize: 9), color: .darkGray, gap: 12)
            if !snapshot.sellerPhone.isEmpty {
                text(snapshot.sellerPhone, font: .systemFont(ofSize: 9), color: .darkGray)
            }
            if !snapshot.sellerEmail.isEmpty {
                text(snapshot.sellerEmail, font: .systemFont(ofSize: 9), color: .darkGray, gap: 10)
            }

            if case let .invoice(number, issuedAt, dueDate, _) = kind {
                text(localized("Invoice number") + ": " + number, font: .boldSystemFont(ofSize: 11))
                text(localized("Invoice date") + ": " + issuedAt.formatted(.dateTime.day().month().year().locale(locale)), font: .systemFont(ofSize: 10))
                text(localized("Due date") + ": " + dueDate.formatted(.dateTime.day().month().year().locale(locale)), font: .systemFont(ofSize: 10))
            } else if case let .invoiceDraft(dueDate) = kind {
                text(localized("Due date") + ": " + dueDate.formatted(.dateTime.day().month().year().locale(locale)), font: .systemFont(ofSize: 10))
            } else if case let .creditNote(number, issuedAt, originalInvoiceNumber) = kind {
                text(localized("Credit note number") + ": " + number, font: .boldSystemFont(ofSize: 11))
                text(localized("Credit note date") + ": " + issuedAt.formatted(.dateTime.day().month().year().locale(locale)), font: .systemFont(ofSize: 10))
                text(localized("Credits invoice") + ": " + originalInvoiceNumber, font: .systemFont(ofSize: 10))
            } else if case let .acceptedBid(acceptedAt) = kind {
                text(localized("Accepted on") + ": " + acceptedAt.formatted(.dateTime.day().month().year().locale(locale)), font: .systemFont(ofSize: 10))
            } else {
                text(localized("Date") + ": " + Date.now.formatted(.dateTime.day().month().year().locale(locale)), font: .systemFont(ofSize: 10))
            }
            text(localized("Customer") + ": " + snapshot.customerName, font: .boldSystemFont(ofSize: 11), gap: 3)
            if !snapshot.customerOrganizationNumber.isEmpty {
                text(localized("Org. no.") + ": " + snapshot.customerOrganizationNumber, font: .systemFont(ofSize: 10))
            }
            text(snapshot.customerAddress, font: .systemFont(ofSize: 10))
            text(localized("Job number") + ": " + snapshot.jobNumber, font: .systemFont(ofSize: 10))
            text(snapshot.jobTitle, font: .systemFont(ofSize: 10))
            text(localized("Delivery date") + ": " + snapshot.deliveryDate.formatted(.dateTime.day().month().year().locale(locale)), font: .systemFont(ofSize: 10))
            text(localized("Delivery address") + ": " + snapshot.deliveryAddress, font: .systemFont(ofSize: 10), gap: 14)

            for line in snapshot.lines {
                if y > page.height - 150 { beginPage() }
                let number = line.itemNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let title = number.isEmpty ? line.description : "\(number) · \(line.description)"
                text(title, font: .boldSystemFont(ofSize: 10), gap: 2)
                let quantity = EntryFormatting.formatDecimal(line.quantity, locale: locale)
                let vat = EntryFormatting.formatDecimal(line.vatRatePercent, locale: locale)
                let lineSubtotal = isCreditNote(kind) ? -line.subtotal : line.subtotal
                let unit = MaterialUnit(rawValue: line.unit).map(localizedUnit) ?? line.unit
                text("\(quantity) \(unit) × \(money(line.unitPrice)) · \(localized("VAT")) \(vat)% = \(money(lineSubtotal))", font: .systemFont(ofSize: 9), color: .darkGray, gap: 7)
            }
            y += 8
            let sign: Decimal = isCreditNote(kind) ? -1 : 1
            text(localized("Subtotal excluding VAT") + ": " + money(snapshot.subtotal * sign), font: .systemFont(ofSize: 11))
            text(localized("VAT") + ": " + money(snapshot.vat * sign), font: .systemFont(ofSize: 11))
            text(localized("Total") + ": " + money(snapshot.total * sign), font: .boldSystemFont(ofSize: 14), gap: 12)
            switch kind {
            case .invoice, .invoiceDraft:
                let account = snapshot.sellerBankAccount.isEmpty ? localized("Not specified") : snapshot.sellerBankAccount
                if snapshot.exerciseMode != true {
                    text(localized("Bank account") + ": " + account, font: .boldSystemFont(ofSize: 11))
                }
            default: break
            }
        }
        return url
    }

    private func outputURL(snapshot: SalesDocumentSnapshot, kind: Kind) throws -> URL {
        if case .invoiceDraft = kind {
            let directory = FileManager.default.temporaryDirectory.appending(path: "JobbBevis-Drafts", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appending(path: "Fakturautkast-\(snapshot.jobNumber)-\(UUID().uuidString.prefix(8)).pdf")
        }
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appending(path: "JobbBevis/Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let prefix: String
            switch kind {
            case .bid: prefix = "Anbud-\(snapshot.jobNumber)"
            case .acceptedBid: prefix = "Akseptert-anbud-\(snapshot.jobNumber)"
            case .orderConfirmation: prefix = "Ordrebekreftelse-\(snapshot.jobNumber)"
        case .invoiceDraft: prefix = "Fakturautkast-\(snapshot.jobNumber)"
        case let .invoice(number, _, _, isCopy):
            prefix = isCopy ? "Fakturakopi-\(number)" : "Faktura-\(number)"
        case let .creditNote(number, _, _):
            prefix = "Kreditnota-\(number)"
        }
        return directory.appending(path: "\(prefix)-\(UUID().uuidString.prefix(8)).pdf")
    }

    private func isCreditNote(_ kind: Kind) -> Bool {
        if case .creditNote = kind { return true }
        return false
    }
}
