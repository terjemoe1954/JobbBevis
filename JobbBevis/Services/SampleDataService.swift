import SwiftData
import UIKit

@MainActor
struct SampleDataService {
    private let projectNumber = "HM-2026-001"

    func hasSampleData(in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<JobRecord>()).contains {
            $0.jobNumber == projectNumber && $0.isSampleData
        }
    }

    func load(in context: ModelContext) async throws {
        let jobs = try context.fetch(FetchDescriptor<JobRecord>())
        if let existing = jobs.first(where: { $0.jobNumber == projectNumber }) {
            throw existing.isSampleData ? SampleDataError.alreadyLoaded : SampleDataError.identifierConflict(projectNumber)
        }
        let customers = try context.fetch(FetchDescriptor<Customer>())
        if let customer = customers.first(where: { $0.customerNumber == "K-001" }), !customer.isSampleData {
            throw SampleDataError.identifierConflict("K-001")
        }
        let existingSupplierNumbers = Set(try context.fetch(FetchDescriptor<Supplier>()).map(\.supplierNumber))
        let existingProductNumbers = Set(try context.fetch(FetchDescriptor<ProductCatalogItem>()).compactMap(\.itemNumber))
        guard existingSupplierNumbers.isDisjoint(with: reservedSupplierNumbers),
              existingProductNumbers.isDisjoint(with: Set(products.map(\.id))) else {
            throw SampleDataError.identifierConflict("DEMO register ID")
        }

        var createdPaths: [String] = []
        do {
            let customer = customers.first(where: { $0.customerNumber == "K-001" }) ?? Customer(
                customerNumber: "K-001",
                name: "Arne Elliassen",
                isSampleData: true
            )
            if customer.modelContext == nil { context.insert(customer) }
            let job = JobRecord(
                jobNumber: projectNumber,
                title: "Totalrenovering hytte Hvasser",
                customer: customer,
                workAddress: "Hvasserveien 100 – FIKTIV TESTADRESSE, 3148 Hvasser",
                details: """
                DEMO – fiktivt prosjekt. HandyMe er hovedentreprenør. Hovedentreprise for 85 m² hytte og 22 m² veranda.
                Tilbudsramme 1 274 200 kr eks. mva., inkludert reserve 166 200 kr. Reise/overnatting avtales separat (12 tur-retur, 4 560 km og 72 planlagte timer).
                Anbud AN-001: Utkast – ikke sendt. Ordrebekreftelse OB-001: Utkast – ikke signert eller akseptert.
                Testadressen er ikke bekreftet. Befaring og tillatelser må avklares. Elektroarbeid krever kvalifisert registrert virksomhet.
                """,
                status: .planned,
                isSampleData: true,
                estimatedHours: 905,
                drivingKilometers: 4_560,
                vatRatePercent: 25,
                hasInvoiceDraft: false
            )
            job.projectMode = .mainContract
            context.insert(job)

            let trades = makeTrades(job: job)
            trades.values.forEach(context.insert)
            job.projectTrades.append(contentsOf: trades.values)

            let suppliers = makeSuppliers()
            suppliers.values.forEach(context.insert)
            let parties = makeParties(job: job, trades: trades, suppliers: suppliers)
            parties.values.forEach(context.insert)
            job.projectParties.append(contentsOf: parties.values)

            let workPackages = makeWorkPackages(job: job, trades: trades, parties: parties)
            workPackages.forEach(context.insert)
            job.workPackages.append(contentsOf: workPackages)

            for product in products {
                guard let supplier = suppliers[product.supplierID] else { continue }
                context.insert(ProductCatalogItem(
                    itemNumber: product.id,
                    supplier: supplier.name,
                    supplierRecord: supplier,
                    name: product.name,
                    unit: product.unit,
                    unitPrice: product.price
                ))
            }
            for purchase in purchases {
                guard let product = products.first(where: { $0.id == purchase.productID }),
                      let supplier = suppliers[product.supplierID] else { continue }
                let item = PurchaseItem(
                    supplier: supplier.name,
                    itemName: product.name,
                    quantity: purchase.count,
                    unit: product.unit,
                    unitPrice: product.price,
                    note: "DEMO \(purchase.id) · \(purchase.productID) · \(purchase.packageID) · Planlagt, ikke innkjøpt",
                    job: job
                )
                context.insert(item)
                job.purchaseItems.append(item)
            }
            for (index, photo) in photos.enumerated() {
                let path = try await PhotoFileStore().importImageData(
                    illustration(symbol: photo.symbol, color: photo.color),
                    jobID: job.id
                )
                createdPaths.append(path)
                let record = JobPhoto(
                    relativePath: path,
                    category: photo.category,
                    caption: "\(photo.id) · \(photo.packageID) · AI-illustrasjon, ikke reelt foto",
                    sortOrder: index,
                    job: job
                )
                context.insert(record)
                job.photos.append(record)
            }
            try context.save()
        } catch {
            createdPaths.forEach { try? PhotoFileStore().remove(relativePath: $0) }
            context.rollback()
            throw error
        }
    }

    func remove(in context: ModelContext) throws {
        let demoJobs = try context.fetch(FetchDescriptor<JobRecord>()).filter {
            $0.jobNumber == projectNumber && $0.isSampleData
        }
        for job in demoJobs {
            try PhotoFileStore().removeAll(for: job)
            context.delete(job)
        }
        let productIDs = Set(products.map(\.id))
        try context.fetch(FetchDescriptor<ProductCatalogItem>()).filter {
            $0.itemNumber.map(productIDs.contains) ?? false
        }.forEach(context.delete)
        try context.save()
        try context.fetch(FetchDescriptor<Supplier>()).filter {
            reservedSupplierNumbers.contains($0.supplierNumber)
        }.forEach(context.delete)
        try context.fetch(FetchDescriptor<Customer>()).filter {
            $0.customerNumber == "K-001" && $0.isSampleData && $0.jobs.isEmpty
        }.forEach(context.delete)
        try context.save()
    }

    private func makeTrades(job: JobRecord) -> [String: ProjectTrade] {
        [
            "F-T": ProjectTrade(code: "F-T", name: "Tømrer", isInternal: true, plannedHours: 365, job: job),
            "F-M": ProjectTrade(code: "F-M", name: "Maler", plannedHours: 210, job: job),
            "F-E": ProjectTrade(code: "F-E", name: "Elektriker", plannedHours: 200, job: job),
            "F-R": ProjectTrade(code: "F-R", name: "Rørlegger", plannedHours: 130, job: job)
        ]
    }

    private func makeSuppliers() -> [String: Supplier] {
        let values = [
            ("PART-00", "HandyMe"), ("PART-01", "HandyMe tømrerteam"),
            ("PART-02", "Malerfirma (test)"), ("PART-03", "Elektrofirma (test)"),
            ("PART-04", "Rørleggerfirma (test)"), ("L-01", "Byggevarehandel (test)"),
            ("L-02", "Malingshandel (test)"), ("L-03", "Kjøkkenleverandør (test)"),
            ("L-04", "Elektrogrossist (test)"), ("L-05", "VVS-grossist (test)")
        ]
        return Dictionary(uniqueKeysWithValues: values.map {
            ($0.0, Supplier(supplierNumber: $0.0, name: $0.1))
        })
    }

    private func makeParties(job: JobRecord, trades: [String: ProjectTrade], suppliers: [String: Supplier]) -> [String: ProjectParty] {
        [
            "PART-00": ProjectParty(role: .mainContractor, contactPerson: "Intern prosjektleder", note: "HandyMe er hovedentreprenør", job: job, supplier: suppliers["PART-00"]),
            "PART-01": ProjectParty(role: .internalResource, note: "Testpart", job: job, supplier: suppliers["PART-01"], trade: trades["F-T"]),
            "PART-02": ProjectParty(role: .subcontractor, note: "Fiktiv leverandør", job: job, supplier: suppliers["PART-02"], trade: trades["F-M"]),
            "PART-03": ProjectParty(role: .subcontractor, note: "Krever registrert elektrovirksomhet", job: job, supplier: suppliers["PART-03"], trade: trades["F-E"]),
            "PART-04": ProjectParty(role: .subcontractor, note: "Fiktiv leverandør", job: job, supplier: suppliers["PART-04"], trade: trades["F-R"])
        ]
    }

    private func makeWorkPackages(job: JobRecord, trades: [String: ProjectTrade], parties: [String: ProjectParty]) -> [WorkPackage] {
        let values: [(String, String, String, String, Decimal, Decimal, String)] = [
            ("AP-01", "Rigg, beskyttelse og avfall", "F-T", "PART-01", 52_000, 80, ""),
            ("AP-02", "Male vegger og tak", "F-M", "PART-02", 128_000, 210, ""),
            ("AP-03", "Nytt kjøkken, leveranse og montering", "F-T", "PART-01", 272_000, 150, ""),
            ("AP-04", "Elektrisk anlegg, lys og kontroll", "F-E", "PART-03", 224_000, 160, "Kontroll: Samsvarserklæring elektro – ikke startet"),
            ("AP-05", "Vannrør og varmtvannsbereder", "F-R", "PART-04", 144_000, 130, "Kontroll: VVS-dokumentasjon og lekkasjekontroll – ikke startet"),
            ("AP-06", "Varmeovner og styring", "F-E", "PART-03", 48_000, 40, ""),
            ("AP-07", "Rive og bygge veranda 22 m²", "F-T", "PART-01", 192_000, 110, "Kontroll: Konstruksjon og rekkverk – ikke startet"),
            ("AP-08", "Prosjektledelse og koordinering", "F-T", "PART-00", 48_000, 25, "Kontroll: Sluttbefaring og FDV – ikke startet")
        ]
        return values.map {
            WorkPackage(packageNumber: $0.0, title: $0.1, details: $0.6, status: .planned,
                        progressPercent: 0, budgetExcludingVAT: $0.4, plannedHours: $0.5,
                        job: job, trade: trades[$0.2], responsibleParty: parties[$0.3])
        }
    }

    private func illustration(symbol: String, color: UIColor) throws -> Data {
        let size = CGSize(width: 1_200, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.withAlphaComponent(0.18).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let configuration = UIImage.SymbolConfiguration(pointSize: 260, weight: .regular)
            UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 440, y: 240, width: 320, height: 320))
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw SampleDataError.imageCreationFailed
        }
        return data
    }

    private var reservedSupplierNumbers: Set<String> {
        Set(["PART-00", "PART-01", "PART-02", "PART-03", "PART-04", "L-01", "L-02", "L-03", "L-04", "L-05"])
    }

    private var products: [DemoProduct] {
        [
            .init("V-01", "Terrasseskruer A4 (200 stk/eske)", "eske", 399, "L-01"),
            .init("V-02", "Terrassebord (4,8 meter/stk)", "stk", 249, "L-01"),
            .init("V-03", "Utendørs beis (9 liter/spann)", "spann", 1_190, "L-02"),
            .init("V-04", "Innendørs maling (9 liter/spann)", "spann", 1_290, "L-02"),
            .init("V-05", "Sparkel (10 liter/spann)", "spann", 520, "L-02"),
            .init("V-06", "Kjøkkeninnredning premium", "sett", 145_000, "L-03"),
            .init("V-07", "Hvitevarer premium", "sett", 65_000, "L-03"),
            .init("V-08", "Elektrisk kabel (100 meter/kveil)", "kveil", 5_900, "L-04"),
            .init("V-09", "LED downlight", "stk", 650, "L-04"),
            .init("V-10", "Panelovn", "stk", 2_900, "L-04"),
            .init("V-11", "Vannrør PEX (50 meter/kveil)", "kveil", 3_900, "L-05"),
            .init("V-12", "Varmtvannsbereder", "stk", 13_500, "L-05")
        ]
    }

    private var purchases: [DemoPurchase] {
        let values: [(String, String, String, Decimal)] = [
            ("H-01", "AP-07", "V-01", 3), ("H-02", "AP-07", "V-02", 38),
            ("H-03", "AP-07", "V-03", 2), ("H-04", "AP-02", "V-04", 5),
            ("H-05", "AP-02", "V-05", 2), ("H-06", "AP-03", "V-06", 1),
            ("H-07", "AP-03", "V-07", 1), ("H-08", "AP-04", "V-08", 2),
            ("H-09", "AP-04", "V-09", 24), ("H-10", "AP-06", "V-10", 5),
            ("H-11", "AP-05", "V-11", 2), ("H-12", "AP-05", "V-12", 1)
        ]
        return values.map(DemoPurchase.init)
    }

    private var photos: [DemoPhoto] {
        [
            .init("B-01", "AP-03", .after, "cabinet.fill", .systemOrange), .init("B-02", "AP-03", .before, "cabinet", .systemOrange),
            .init("B-03", "AP-07", .after, "house.fill", .systemBrown), .init("B-04", "AP-02", .before, "paintbrush", .systemIndigo),
            .init("B-05", "AP-02", .after, "paintbrush.fill", .systemIndigo), .init("B-06", "AP-07", .after, "hammer.fill", .systemBrown),
            .init("B-07", "AP-07", .before, "hammer", .systemBrown), .init("B-08", "AP-02", .after, "paintbrush.fill", .systemPurple),
            .init("B-09", "AP-07", .before, "house", .systemBrown), .init("B-10", "AP-02", .before, "paintbrush", .systemBlue),
            .init("B-11", "AP-02", .before, "paintbrush", .systemPurple), .init("B-12", "AP-04", .before, "bolt", .systemYellow),
            .init("B-13", "AP-02", .after, "paintbrush.fill", .systemBlue), .init("B-14", "AP-04", .after, "bolt.fill", .systemYellow)
        ]
    }
}

private struct DemoProduct {
    let id: String; let name: String; let unit: String; let price: Decimal; let supplierID: String
    init(_ id: String, _ name: String, _ unit: String, _ price: Decimal, _ supplierID: String) {
        self.id = id; self.name = name; self.unit = unit; self.price = price; self.supplierID = supplierID
    }
}

private struct DemoPurchase {
    let id: String; let packageID: String; let productID: String; let count: Decimal
}

private struct DemoPhoto {
    let id: String; let packageID: String; let category: PhotoCategory; let symbol: String; let color: UIColor
    init(_ id: String, _ packageID: String, _ category: PhotoCategory, _ symbol: String, _ color: UIColor) {
        self.id = id; self.packageID = packageID; self.category = category; self.symbol = symbol; self.color = color
    }
}

enum SampleDataError: LocalizedError {
    case alreadyLoaded
    case identifierConflict(String)
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .alreadyLoaded: String(localized: "The Hvasser DEMO project is already loaded.")
        case .identifierConflict(let id): String(localized: "Existing data already uses identifier \(id). Nothing was changed.")
        case .imageCreationFailed: String(localized: "The sample image could not be created.")
        }
    }
}
