#if DEBUG
import Foundation
import SwiftData

@MainActor
public enum CoreTestSupport {
    public static func formattedDuration(totalMinutes: Int) -> String {
        EntryFormatting.duration(totalMinutes: totalMinutes)
    }

    public static func norwegianNumbersAreValidated() -> Bool {
        NorwegianNumberValidator.organizationNumberDigits(from: "123 456 785") == "123456785"
            && NorwegianNumberValidator.organizationNumberDigits(from: "123 456 789") == nil
            && NorwegianNumberValidator.bankAccountDigits(from: "1234.45.68454") == "12344568454"
            && NorwegianNumberValidator.bankAccountDigits(from: "1234.45.68455") == nil
    }

    public static func nextJobNumbers() throws -> [String] {
        let context = try makeContext()
        return [
            try JobNumberService.nextNumber(in: context),
            try JobNumberService.nextNumber(in: context)
        ]
    }

    public static func relationshipsPersist() throws -> Bool {
        let context = try makeContext()
        let customer = Customer(name: "Test customer")
        let job = JobRecord(jobNumber: "TEST-1", title: "Test job", customer: customer)
        job.workEntries.append(
            WorkEntry(workDate: .now, details: "Work", durationMinutes: 75, job: job)
        )
        job.materialEntries.append(
            MaterialEntry(name: "Board", quantity: 2, unit: "pcs", job: job)
        )
        job.purchaseItems.append(
            PurchaseItem(
                supplier: "Supplier",
                itemName: "Screws",
                quantity: 3,
                unit: "package",
                unitPrice: 99,
                job: job
            )
        )
        context.insert(customer)
        context.insert(job)
        try context.save()

        guard let stored = try context.fetch(FetchDescriptor<JobRecord>()).first else {
            return false
        }
        return stored.customer.name == "Test customer"
            && stored.workEntries.first?.durationMinutes == 75
            && stored.materialEntries.first?.quantity == 2
            && stored.purchaseItems.first?.supplier == "Supplier"
    }

    public static func workAndMaterialEntriesCanBeDeleted() throws -> Bool {
        let context = try makeContext()
        let customer = Customer(name: "Delete test")
        let job = JobRecord(jobNumber: "DELETE-1", title: "Delete test", customer: customer)
        let workEntry = WorkEntry(workDate: .now, details: "Work", durationMinutes: 60, job: job)
        let materialEntry = MaterialEntry(name: "Material", quantity: 1, unit: "pcs", job: job)
        job.workEntries.append(workEntry)
        job.materialEntries.append(materialEntry)
        context.insert(customer)
        context.insert(job)
        try context.save()

        job.workEntries.removeAll { $0.id == workEntry.id }
        job.materialEntries.removeAll { $0.id == materialEntry.id }
        context.delete(workEntry)
        context.delete(materialEntry)
        try context.save()

        let storedWorkEntries = try context.fetch(FetchDescriptor<WorkEntry>())
        let storedMaterialEntries = try context.fetch(FetchDescriptor<MaterialEntry>())
        return job.workEntries.isEmpty
            && job.materialEntries.isEmpty
            && storedWorkEntries.isEmpty
            && storedMaterialEntries.isEmpty
    }

    public static func backupRoundTripPreservesData() throws -> Bool {
        let source = try makeContext()
        let customer = Customer(
            customerNumber: "K-0001", name: "Example", address: "Customer Road 1", isSampleData: true
        )
        let company = CompanyProfile(
            name: "Company", organizationNumber: "123456785", address: "Company Road 2",
            bankAccount: "1234.45.68454", isVATRegistered: true,
            defaultHourlyRate: 875, defaultDrivingRatePerKilometer: 6.5
        )
        let job = JobRecord(
            jobNumber: "DEMO-1",
            title: "Example job",
            customer: customer,
            isSampleData: true,
            estimatedHours: 4,
            hourlyRate: 750,
            drivingKilometers: 20,
            drivingRatePerKilometer: 5,
            vatRatePercent: 25
        )
        job.materialEntries.append(
            MaterialEntry(name: "Material", quantity: 3, unit: "pcs", job: job, unitPrice: 100)
        )
        job.purchaseItems.append(
            PurchaseItem(
                supplier: "Supplier",
                itemName: "Purchase",
                quantity: 2,
                unit: "pcs",
                unitPrice: 125,
                job: job
            )
        )
        source.insert(company)
        source.insert(customer)
        source.insert(job)
        let supplier = Supplier(supplierNumber: "L-0001", name: "Catalog Supplier")
        source.insert(supplier)
        source.insert(ProductCatalogItem(
            itemNumber: "V-0001", supplier: supplier.name, supplierRecord: supplier,
            name: "Catalog Product", unit: "pcs", unitPrice: 299
        ))
        try source.save()
        _ = try SalesDocumentService.issueInvoice(
            job: job, company: company, dueDate: .now.addingTimeInterval(14 * 86_400), in: source
        )
        job.archivedAt = .now
        try source.save()

        let service = BackupService()
        let prepared = try service.prepareImport(data: service.exportData(from: source))
        let destination = try makeContext()
        try service.restore(prepared, into: destination)

        guard let restored = try destination.fetch(FetchDescriptor<JobRecord>()).first else {
            return false
        }
        let restoredProduct = try destination.fetch(FetchDescriptor<ProductCatalogItem>()).first
        let restoredInvoice = try destination.fetch(FetchDescriptor<InvoiceRecord>()).first
        let restoredCompany = try destination.fetch(FetchDescriptor<CompanyProfile>()).first
        return prepared.summary.customers == 1
            && prepared.summary.jobs == 1
            && restored.customer.name == "Example"
            && restored.customer.customerNumber == "K-0001"
            && restored.isSampleData
            && restored.customer.isSampleData
            && restored.estimatedHours == 4
            && restored.hourlyRate == 750
            && restored.drivingKilometers == 20
            && restored.drivingRatePerKilometer == 5
            && restored.vatRatePercent == 25
            && restored.isArchived
            && restored.materialEntries.first?.unitPrice == 100
            && restored.purchaseItems.first?.lineTotal == 250
            && restoredProduct?.name == "Catalog Product"
            && restoredProduct?.itemNumber == "V-0001"
            && restoredProduct?.supplierRecord?.supplierNumber == "L-0001"
            && restoredInvoice?.snapshot?.customerName == "Example"
            && restoredInvoice?.invoiceNumber.hasSuffix("00001") == true
            && restoredCompany?.defaultHourlyRate == 875
            && restoredCompany?.defaultDrivingRatePerKilometer == 6.5
    }

    public static func priceEstimateTotalsAreCorrect() throws -> Bool {
        let context = try makeContext()
        let customer = Customer(name: "Price test")
        let job = JobRecord(
            jobNumber: "PRICE-1",
            title: "Price test",
            customer: customer,
            estimatedHours: 10,
            hourlyRate: 800,
            drivingKilometers: 50,
            drivingRatePerKilometer: 5,
            vatRatePercent: 25
        )
        job.materialEntries.append(
            MaterialEntry(name: "Material", quantity: 2, unit: "pcs", job: job, unitPrice: 500)
        )
        context.insert(customer)
        context.insert(job)
        try context.save()

        let estimate = PriceEstimateCalculator.estimate(for: job)
        return estimate.labor == 8_000
            && estimate.materials == 1_000
            && estimate.driving == 250
            && estimate.subtotal == 9_250
            && estimate.vat == 2_312.5
            && estimate.total == 11_562.5
    }

    public static func invoicesAreUniqueSequentialAndImmutable() throws -> Bool {
        let context = try makeContext()
        let company = CompanyProfile(
            name: "Test Company", organizationNumber: "123456785", address: "Seller Street 1",
            bankAccount: "1234.45.68454", isVATRegistered: true
        )
        let customer = Customer(name: "Original Customer", address: "Customer Street 2")
        let job = JobRecord(
            jobNumber: "INV-TEST", title: "Invoice test", customer: customer,
            estimatedHours: 2, hourlyRate: 1_000, vatRatePercent: 25
        )
        let secondJob = JobRecord(
            jobNumber: "INV-TEST-2", title: "Second invoice test", customer: customer,
            estimatedHours: 1, hourlyRate: 500, vatRatePercent: 25
        )
        context.insert(company)
        context.insert(customer)
        context.insert(job)
        context.insert(secondJob)
        let first = try SalesDocumentService.issueInvoice(
            job: job, company: company, dueDate: .now.addingTimeInterval(14 * 86_400), in: context
        )
        customer.name = "Changed Customer"
        let duplicateWasRejected: Bool
        do {
            _ = try SalesDocumentService.issueInvoice(
                job: job, company: company, dueDate: .now.addingTimeInterval(14 * 86_400), in: context
            )
            duplicateWasRejected = false
        } catch SalesDocumentError.invoiceAlreadyIssued {
            duplicateWasRejected = true
        }
        let second = try SalesDocumentService.issueInvoice(
            job: secondJob, company: company, dueDate: .now.addingTimeInterval(14 * 86_400), in: context
        )
        let creditNote = try SalesDocumentService.issueCreditNote(for: first, in: context)
        let duplicateCreditWasRejected: Bool
        do {
            _ = try SalesDocumentService.issueCreditNote(for: first, in: context)
            duplicateCreditWasRejected = false
        } catch SalesDocumentError.creditNoteAlreadyIssued {
            duplicateCreditWasRejected = true
        }
        return first.invoiceNumber.hasSuffix("00001")
            && second.invoiceNumber.hasSuffix("00002")
            && duplicateWasRejected
            && creditNote.creditNoteNumber.hasSuffix("00001")
            && creditNote.originalInvoiceNumber == first.invoiceNumber
            && creditNote.snapshot?.total == first.snapshot?.total
            && duplicateCreditWasRejected
            && first.snapshot?.customerName == "Original Customer"
            && first.snapshot?.total == 2_500
    }

    public static func accountingCSVContainsInvoiceLines() throws -> Bool {
        let snapshot = SalesDocumentSnapshot(
            sellerName: "Test Company",
            sellerOrganizationNumber: "123456785",
            sellerAddress: "Seller Street 1",
            sellerPhone: "",
            sellerEmail: "",
            sellerBankAccount: "1234.45.68454",
            sellerIsVATRegistered: true,
            sellerIsRegisteredInBusinessRegister: true,
            customerName: "Customer, AS",
            customerOrganizationNumber: "987654321",
            customerAddress: "Customer Street 2",
            jobNumber: "JB-0001",
            jobTitle: "CSV test",
            deliveryDate: Date(timeIntervalSince1970: 0),
            deliveryAddress: "Customer Street 2",
            lines: [
                SalesDocumentLine(
                    id: UUID(), description: "Work \"including materials\"", quantity: 2,
                    unit: "h", unitPrice: 1_000, vatRatePercent: 25
                )
            ]
        )
        let invoice = InvoiceRecord(
            invoiceNumber: "2026-00001",
            jobID: UUID(),
            jobNumber: "JB-0001",
            issuedAt: Date(timeIntervalSince1970: 0),
            dueDate: Date(timeIntervalSince1970: 86_400),
            snapshotData: try JSONEncoder().encode(snapshot)
        )
        let data = try AccountingCSVExportService().exportData(invoices: [invoice])
        guard let csv = String(data: data, encoding: .utf8) else { return false }
        return csv.contains("\"invoice_number\"")
            && csv.contains("\"2026-00001\"")
            && csv.contains("\"Customer, AS\"")
            && csv.contains("\"Work \"\"including materials\"\"\"")
            && csv.contains("\"2500\"")
    }

    public static func accountingReportIsPDF() throws -> Bool {
        let snapshot = SalesDocumentSnapshot(
            sellerName: "Test Company",
            sellerOrganizationNumber: "123456785",
            sellerAddress: "Seller Street 1",
            sellerPhone: "",
            sellerEmail: "",
            sellerBankAccount: "1234.45.68454",
            sellerIsVATRegistered: true,
            sellerIsRegisteredInBusinessRegister: true,
            customerName: "Test Customer",
            customerOrganizationNumber: "987654321",
            customerAddress: "Customer Street 2",
            jobNumber: "JB-0001",
            jobTitle: "PDF test",
            deliveryDate: .now,
            deliveryAddress: "Customer Street 2",
            lines: [
                SalesDocumentLine(
                    id: UUID(), description: "Work", quantity: 2,
                    unit: "h", unitPrice: 1_000, vatRatePercent: 25
                )
            ]
        )
        let invoice = InvoiceRecord(
            invoiceNumber: "2026-00001",
            jobID: UUID(),
            jobNumber: "JB-0001",
            issuedAt: .now,
            dueDate: .now.addingTimeInterval(86_400),
            snapshotData: try JSONEncoder().encode(snapshot)
        )
        let data = try AccountingReportPDFService().exportData(
            invoices: [invoice],
            locale: Locale(identifier: "nb_NO")
        )
        return data.count > 1_000 && data.starts(with: Data("%PDF".utf8))
    }

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([
            CompanyProfile.self,
            Customer.self,
            JobRecord.self,
            JobPhoto.self,
            WorkEntry.self,
            MaterialEntry.self,
            PurchaseItem.self,
            Supplier.self,
            ProductCatalogItem.self,
            InvoiceRecord.self,
            CreditNoteRecord.self,
            AppMetadata.self
        ])
        let configuration = ModelConfiguration(
            "JobbBevisTests-\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }
}
#endif
