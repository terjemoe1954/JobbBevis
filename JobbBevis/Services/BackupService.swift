import CryptoKit
import Foundation
import SwiftData

struct BackupSummary: Equatable {
    let createdAt: Date
    let customers: Int
    let jobs: Int
    let photos: Int
    let workEntries: Int
    let materials: Int
    let files: Int
}

struct PreparedBackup {
    fileprivate let archive: BackupArchive
    let summary: BackupSummary
}

@MainActor
struct BackupService {
    static let schemaVersion = 2
    static let maximumArchiveBytes = 250 * 1_024 * 1_024
    private static let maximumFileBytes = 25 * 1_024 * 1_024
    private static let maximumFiles = 5_000
    private static let maximumRecords = 50_000

    func exportData(from context: ModelContext) throws -> Data {
        let profiles = try context.fetch(FetchDescriptor<CompanyProfile>())
        let customers = try context.fetch(FetchDescriptor<Customer>())
        let jobs = try context.fetch(FetchDescriptor<JobRecord>())
        let photos = try context.fetch(FetchDescriptor<JobPhoto>())
        let workEntries = try context.fetch(FetchDescriptor<WorkEntry>())
        let materials = try context.fetch(FetchDescriptor<MaterialEntry>())
        let purchaseItems = try context.fetch(FetchDescriptor<PurchaseItem>())
        let products = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
        let projectTrades = try context.fetch(FetchDescriptor<ProjectTrade>())
        let projectParties = try context.fetch(FetchDescriptor<ProjectParty>())
        let workPackages = try context.fetch(FetchDescriptor<WorkPackage>())
        let invoices = try context.fetch(FetchDescriptor<InvoiceRecord>())
        let creditNotes = try context.fetch(FetchDescriptor<CreditNoteRecord>())
        let metadata = try context.fetch(FetchDescriptor<AppMetadata>())

        var files: [BackupFile] = []
        let fileStore = ManagedFileStore()

        let profileRecords = try profiles.map { profile in
            var logoFileID: UUID?
            if let path = profile.logoRelativePath {
                guard let data = fileStore.data(relativePath: path) else {
                    throw BackupError.missingManagedFile
                }
                let file = try makeFile(kind: .logo, ownerID: profile.id, data: data)
                files.append(file)
                logoFileID = file.id
            }
            return CompanyRecord(
                id: profile.id,
                name: profile.name,
                organizationNumber: profile.organizationNumber,
                phone: profile.phone,
                email: profile.email,
                address: profile.address,
                bankAccount: profile.bankAccount,
                isVATRegistered: profile.isVATRegistered,
                isRegisteredInBusinessRegister: profile.isRegisteredInBusinessRegister,
                defaultHourlyRate: profile.defaultHourlyRate,
                defaultDrivingRatePerKilometer: profile.defaultDrivingRatePerKilometer,
                logoFileID: logoFileID,
                createdAt: profile.createdAt,
                updatedAt: profile.updatedAt
            )
        }

        let photoRecords = try photos.map { photo in
            guard let data = PhotoFileStore().data(relativePath: photo.relativePath) else {
                throw BackupError.missingManagedFile
            }
            let file = try makeFile(kind: .photo, ownerID: photo.id, data: data)
            files.append(file)
            return PhotoRecord(
                id: photo.id,
                jobID: photo.job.id,
                fileID: file.id,
                category: photo.categoryRawValue,
                caption: photo.caption,
                registeredAt: photo.registeredAt,
                sortOrder: photo.sortOrder
            )
        }

        let archive = BackupArchive(
            manifest: BackupManifest(
                format: "JobbBevis Backup",
                schemaVersion: Self.schemaVersion,
                createdAt: .now,
                appVersion: appVersion,
                counts: BackupCounts(
                    companies: profileRecords.count,
                    customers: customers.count,
                    jobs: jobs.count,
                    photos: photoRecords.count,
                    workEntries: workEntries.count,
                    materials: materials.count,
                    purchases: purchaseItems.count,
                    products: products.count,
                    invoices: invoices.count,
                    creditNotes: creditNotes.count,
                    files: files.count
                )
            ),
            companies: profileRecords,
            customers: customers.map {
                CustomerRecord(
                    id: $0.id,
                    customerNumber: $0.customerNumber,
                    name: $0.name,
                    contactPerson: $0.contactPerson,
                    phone: $0.phone,
                    email: $0.email,
                    address: $0.address,
                    organizationNumber: $0.organizationNumber,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    isSampleData: $0.isSampleData
                )
            },
            jobs: jobs.map {
                JobRecordBackup(
                    id: $0.id,
                    customerID: $0.customer.id,
                    jobNumber: $0.jobNumber,
                    title: $0.title,
                    workAddress: $0.workAddress,
                    details: $0.details,
                    plannedDate: $0.plannedDate,
                    status: $0.statusRawValue,
                    completedAt: $0.completedAt,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    isSampleData: $0.isSampleData,
                    estimatedHours: $0.estimatedHours,
                    hourlyRate: $0.hourlyRate,
                    drivingKilometers: $0.drivingKilometers,
                    drivingRatePerKilometer: $0.drivingRatePerKilometer,
                    vatRatePercent: $0.vatRatePercent,
                    hasInvoiceDraft: $0.hasInvoiceDraft,
                    invoiceDraftDueDate: $0.invoiceDraftDueDate,
                    archivedAt: $0.archivedAt
                    , projectMode: $0.projectModeRawValue
                )
            },
            photos: photoRecords,
            workEntries: workEntries.map {
                WorkRecord(
                    id: $0.id,
                    jobID: $0.job.id,
                    workDate: $0.workDate,
                    details: $0.details,
                    durationMinutes: $0.durationMinutes,
                    drivingKilometers: $0.drivingKilometers,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            materials: materials.map {
                MaterialRecord(
                    id: $0.id,
                    jobID: $0.job.id,
                    name: $0.name,
                    quantity: $0.quantity,
                    unit: $0.unit,
                    note: $0.note,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    unitPrice: $0.unitPrice
                )
            },
            purchaseItems: purchaseItems.map {
                PurchaseRecord(
                    id: $0.id,
                    jobID: $0.job.id,
                    supplier: $0.supplier,
                    itemName: $0.itemName,
                    quantity: $0.quantity,
                    unit: $0.unit,
                    unitPrice: $0.unitPrice,
                    note: $0.note,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    transferredMaterialID: $0.transferredMaterialID,
                    transferredAt: $0.transferredAt
                )
            },
            products: products.map {
                ProductRecord(id: $0.id, itemNumber: $0.itemNumber, supplier: $0.supplier,
                              supplierID: $0.supplierRecord?.id, name: $0.name, unit: $0.unit,
                              quantity: $0.quantity, unitPrice: $0.unitPrice,
                              createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            suppliers: suppliers.map {
                SupplierRecord(id: $0.id, supplierNumber: $0.supplierNumber, name: $0.name,
                               contactPerson: $0.contactPerson, phone: $0.phone, email: $0.email,
                               address: $0.address, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            projectTrades: projectTrades.map {
                ProjectTradeBackup(id: $0.id, jobID: $0.job.id, code: $0.code, name: $0.name,
                                   isInternal: $0.isInternal, plannedHours: $0.plannedHours,
                                   createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            projectParties: projectParties.map {
                ProjectPartyBackup(id: $0.id, jobID: $0.job.id, supplierID: $0.supplier?.id,
                                   tradeID: $0.trade?.id, role: $0.roleRawValue,
                                   contactPerson: $0.contactPerson, note: $0.note,
                                   createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            workPackages: workPackages.map {
                WorkPackageBackup(id: $0.id, jobID: $0.job.id, tradeID: $0.trade?.id,
                                  responsiblePartyID: $0.responsibleParty?.id,
                                  packageNumber: $0.packageNumber, title: $0.title,
                                  details: $0.details, status: $0.statusRawValue,
                                  plannedStart: $0.plannedStart, plannedEnd: $0.plannedEnd,
                                  progressPercent: $0.progressPercent,
                                  budgetExcludingVAT: $0.budgetExcludingVAT,
                                  plannedHours: $0.plannedHours,
                                  materialBudgetIncludingVAT: $0.materialBudgetIncludingVAT,
                                  laborBudgetIncludingVAT: $0.laborBudgetIncludingVAT,
                                  createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            invoices: invoices.map {
                InvoiceBackupRecord(id: $0.id, invoiceNumber: $0.invoiceNumber, jobID: $0.jobID,
                                    jobNumber: $0.jobNumber, issuedAt: $0.issuedAt, dueDate: $0.dueDate,
                                    snapshotData: $0.snapshotData)
            },
            creditNotes: creditNotes.map {
                CreditNoteBackupRecord(
                    id: $0.id,
                    creditNoteNumber: $0.creditNoteNumber,
                    originalInvoiceID: $0.originalInvoiceID,
                    originalInvoiceNumber: $0.originalInvoiceNumber,
                    jobNumber: $0.jobNumber,
                    issuedAt: $0.issuedAt,
                    snapshotData: $0.snapshotData
                )
            },
            metadata: metadata.map {
                MetadataRecord(id: $0.id, nextJobSequence: $0.nextJobSequence,
                               nextInvoiceSequence: $0.nextInvoiceSequence,
                               nextCreditNoteSequence: $0.nextCreditNoteSequence)
            },
            files: files
        )

        try validate(archive)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(archive)
        guard data.count <= Self.maximumArchiveBytes else {
            throw BackupError.archiveTooLarge
        }
        return data
    }

    func prepareImport(data: Data) throws -> PreparedBackup {
        guard data.count <= Self.maximumArchiveBytes else {
            throw BackupError.archiveTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive: BackupArchive
        do {
            archive = try decoder.decode(BackupArchive.self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
        try validate(archive)
        return PreparedBackup(archive: archive, summary: summary(for: archive))
    }

    func restore(_ prepared: PreparedBackup, into context: ModelContext) throws {
        let rollbackData = try exportData(from: context)
        let rollbackArchive = try prepareImport(data: rollbackData).archive
        let fileManager = FileManager.default
        let applicationDirectory = try Self.applicationDirectory()
        let operationDirectory = fileManager.temporaryDirectory
            .appending(path: "JobbBevisRestore-\(UUID().uuidString)", directoryHint: .isDirectory)
        let incomingDirectory = operationDirectory.appending(path: "Incoming", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: incomingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: operationDirectory) }

        try stageFiles(for: prepared.archive, at: incomingDirectory)
        try replaceModels(with: prepared.archive, in: context)

        do {
            try replaceManagedFiles(with: prepared.archive, at: applicationDirectory)
        } catch {
            try? replaceModels(with: rollbackArchive, in: context)
            try? replaceManagedFiles(with: rollbackArchive, at: applicationDirectory)
            throw BackupError.restoreFailed
        }
    }

    private func summary(for archive: BackupArchive) -> BackupSummary {
        BackupSummary(
            createdAt: archive.manifest.createdAt,
            customers: archive.customers.count,
            jobs: archive.jobs.count,
            photos: archive.photos.count,
            workEntries: archive.workEntries.count,
            materials: archive.materials.count,
            files: archive.files.count
        )
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func makeFile(kind: BackupFile.Kind, ownerID: UUID, data: Data) throws -> BackupFile {
        guard data.count <= Self.maximumFileBytes else {
            throw BackupError.managedFileTooLarge
        }
        let id = UUID()
        return BackupFile(
            id: id,
            kind: kind,
            ownerID: ownerID,
            archivePath: "files/\(id.uuidString).bin",
            byteCount: data.count,
            sha256: SHA256.hash(data: data).hexString,
            data: data
        )
    }

    private func validate(_ archive: BackupArchive) throws {
        guard archive.manifest.format == "JobbBevis Backup" else {
            throw BackupError.invalidFormat
        }
        guard archive.manifest.schemaVersion == Self.schemaVersion else {
            throw BackupError.unsupportedVersion
        }

        let counts = archive.manifest.counts
        guard counts == BackupCounts(
            companies: archive.companies.count,
            customers: archive.customers.count,
            jobs: archive.jobs.count,
            photos: archive.photos.count,
            workEntries: archive.workEntries.count,
            materials: archive.materials.count,
            purchases: archive.purchaseItems?.count,
            products: archive.products?.count,
            invoices: archive.invoices?.count,
            creditNotes: archive.creditNotes?.count,
            files: archive.files.count
        ) else {
            throw BackupError.countMismatch
        }

        let requiredRecordCount = archive.companies.count + archive.customers.count
            + archive.jobs.count + archive.photos.count + archive.workEntries.count
            + archive.materials.count + archive.metadata.count
        let catalogRecordCount = (archive.purchaseItems?.count ?? 0)
            + (archive.products?.count ?? 0) + (archive.suppliers?.count ?? 0)
        let projectRecordCount = (archive.projectTrades?.count ?? 0)
            + (archive.projectParties?.count ?? 0) + (archive.workPackages?.count ?? 0)
        let documentRecordCount = (archive.invoices?.count ?? 0) + (archive.creditNotes?.count ?? 0)
        let totalRecords = requiredRecordCount + catalogRecordCount
            + projectRecordCount + documentRecordCount
        guard totalRecords <= Self.maximumRecords, archive.files.count <= Self.maximumFiles else {
            throw BackupError.tooManyRecords
        }

        try requireUnique(archive.companies.map(\.id))
        try requireUnique(archive.customers.map(\.id))
        try requireUnique(archive.jobs.map(\.id))
        try requireUnique(archive.jobs.map(\.jobNumber))
        try requireUnique(archive.photos.map(\.id))
        try requireUnique(archive.workEntries.map(\.id))
        try requireUnique(archive.materials.map(\.id))
        try requireUnique((archive.purchaseItems ?? []).map(\.id))
        try requireUnique((archive.products ?? []).map(\.id))
        try requireUnique((archive.products ?? []).compactMap(\.itemNumber))
        try requireUnique((archive.suppliers ?? []).map(\.id))
        try requireUnique((archive.suppliers ?? []).map(\.supplierNumber))
        try requireUnique((archive.projectTrades ?? []).map(\.id))
        try requireUnique((archive.projectParties ?? []).map(\.id))
        try requireUnique((archive.workPackages ?? []).map(\.id))
        try requireUnique((archive.projectTrades ?? []).map { "\($0.jobID)|\($0.code.lowercased())" })
        try requireUnique((archive.workPackages ?? []).map { "\($0.jobID)|\($0.packageNumber.lowercased())" })
        try requireUnique(archive.customers.compactMap(\.customerNumber))
        try requireUnique((archive.invoices ?? []).map(\.id))
        try requireUnique((archive.invoices ?? []).map(\.invoiceNumber))
        try requireUnique((archive.creditNotes ?? []).map(\.id))
        try requireUnique((archive.creditNotes ?? []).map(\.creditNoteNumber))
        try requireUnique((archive.creditNotes ?? []).map(\.originalInvoiceID))
        try requireUnique(archive.metadata.map(\.id))
        try requireUnique(archive.files.map(\.id))
        try requireUnique(archive.files.map(\.archivePath))

        let customerIDs = Set(archive.customers.map(\.id))
        let jobIDs = Set(archive.jobs.map(\.id))
        let invoiceIDs = Set((archive.invoices ?? []).map(\.id))
        let supplierIDs = Set((archive.suppliers ?? []).map(\.id))
        let tradeIDs = Set((archive.projectTrades ?? []).map(\.id))
        let partyIDs = Set((archive.projectParties ?? []).map(\.id))
        let fileIDs = Set(archive.files.map(\.id))
        let validProjectModes = archive.jobs.allSatisfy {
            $0.projectMode.map { ProjectMode(rawValue: $0) != nil } ?? true
        }
        let validTrades = (archive.projectTrades ?? []).allSatisfy {
            jobIDs.contains($0.jobID) && !$0.code.isEmpty && !$0.name.isEmpty
                && ($0.plannedHours.map { $0 >= 0 } ?? true)
        }
        let validParties = (archive.projectParties ?? []).allSatisfy {
            jobIDs.contains($0.jobID)
                && ProjectPartyRole(rawValue: $0.role) != nil
                && ($0.supplierID.map { supplierIDs.contains($0) } ?? true)
                && ($0.tradeID.map { tradeIDs.contains($0) } ?? true)
        }
        let validWorkPackages = (archive.workPackages ?? []).allSatisfy {
            jobIDs.contains($0.jobID) && !$0.packageNumber.isEmpty && !$0.title.isEmpty
                && WorkPackageStatus(rawValue: $0.status) != nil
                && ($0.tradeID.map { tradeIDs.contains($0) } ?? true)
                && ($0.responsiblePartyID.map { partyIDs.contains($0) } ?? true)
                && (0...100).contains($0.progressPercent)
                && ($0.budgetExcludingVAT.map { $0 >= 0 } ?? true)
                && ($0.plannedHours.map { $0 >= 0 } ?? true)
                && ($0.materialBudgetIncludingVAT.map { $0 >= 0 } ?? true)
                && ($0.laborBudgetIncludingVAT.map { $0 >= 0 } ?? true)
        }
        guard archive.jobs.allSatisfy({ customerIDs.contains($0.customerID) }),
              archive.photos.allSatisfy({ jobIDs.contains($0.jobID) && fileIDs.contains($0.fileID) }),
              archive.workEntries.allSatisfy({
                  jobIDs.contains($0.jobID) && $0.durationMinutes > 0
                      && ($0.drivingKilometers.map { $0 >= 0 } ?? true)
              }),
              archive.materials.allSatisfy({
                  jobIDs.contains($0.jobID)
                      && $0.quantity > 0
                      && ($0.unitPrice == nil || $0.unitPrice.map { $0 >= 0 } == true)
              }),
              (archive.purchaseItems ?? []).allSatisfy({
                  jobIDs.contains($0.jobID) && $0.quantity > 0 && $0.unitPrice >= 0
              }),
              (archive.products ?? []).allSatisfy({
                  !$0.supplier.isEmpty && !$0.name.isEmpty && !$0.unit.isEmpty && $0.unitPrice >= 0
                      && $0.supplierID.map { supplierIDs.contains($0) } != false
              }),
              (archive.invoices ?? []).allSatisfy({
                  !$0.invoiceNumber.isEmpty && !$0.jobNumber.isEmpty
                      && (try? JSONDecoder().decode(SalesDocumentSnapshot.self, from: $0.snapshotData)) != nil
              }),
              (archive.creditNotes ?? []).allSatisfy({
                  invoiceIDs.contains($0.originalInvoiceID)
                      && !$0.creditNoteNumber.isEmpty
                      && !$0.originalInvoiceNumber.isEmpty
                      && (try? JSONDecoder().decode(SalesDocumentSnapshot.self, from: $0.snapshotData)) != nil
              }),
              archive.jobs.allSatisfy({ record in
                  [
                      record.estimatedHours,
                      record.hourlyRate,
                      record.drivingKilometers,
                      record.drivingRatePerKilometer,
                      record.vatRatePercent
                  ].compactMap { $0 }.allSatisfy { $0 >= 0 }
              }),
              archive.jobs.allSatisfy({ JobStatus(rawValue: $0.status) != nil }),
              validProjectModes, validTrades, validParties, validWorkPackages
        else {
            throw BackupError.invalidReferences
        }

        let fileByID = Dictionary(uniqueKeysWithValues: archive.files.map { ($0.id, $0) })
        for company in archive.companies {
            if let fileID = company.logoFileID {
                guard let file = fileByID[fileID], file.kind == .logo, file.ownerID == company.id else {
                    throw BackupError.invalidReferences
                }
            }
        }
        for photo in archive.photos {
            guard let file = fileByID[photo.fileID], file.kind == .photo, file.ownerID == photo.id,
                  PhotoCategory(rawValue: photo.category) != nil else {
                throw BackupError.invalidReferences
            }
        }

        let referencedFiles = Set(archive.companies.compactMap(\.logoFileID) + archive.photos.map(\.fileID))
        guard referencedFiles == fileIDs else {
            throw BackupError.invalidReferences
        }

        var totalFileBytes = 0
        for file in archive.files {
            guard isSafeArchivePath(file.archivePath),
                  file.data.count == file.byteCount,
                  file.byteCount <= Self.maximumFileBytes,
                  SHA256.hash(data: file.data).hexString == file.sha256
            else {
                throw BackupError.invalidManagedFile
            }
            totalFileBytes += file.byteCount
            guard totalFileBytes <= Self.maximumArchiveBytes else {
                throw BackupError.archiveTooLarge
            }
        }
    }

    private func requireUnique<T: Hashable>(_ values: [T]) throws {
        guard Set(values).count == values.count else {
            throw BackupError.duplicateIdentifier
        }
    }

    private func isSafeArchivePath(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count == 2
            && components[0] == "files"
            && !components[1].isEmpty
            && !components.contains("..")
            && !path.hasPrefix("/")
            && !path.contains("\\")
    }

    private func stageFiles(for archive: BackupArchive, at root: URL) throws {
        let photosDirectory = root.appending(path: "Photos", directoryHint: .isDirectory)
        let logosDirectory = root.appending(path: "Logos", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logosDirectory, withIntermediateDirectories: true)

        let photoByID = Dictionary(uniqueKeysWithValues: archive.photos.map { ($0.fileID, $0) })
        for file in archive.files {
            let destination: URL
            switch file.kind {
            case .logo:
                destination = logosDirectory.appending(path: "\(file.ownerID.uuidString).image")
            case .photo:
                guard let photo = photoByID[file.id] else { throw BackupError.invalidReferences }
                let jobDirectory = photosDirectory.appending(path: photo.jobID.uuidString, directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: jobDirectory, withIntermediateDirectories: true)
                destination = jobDirectory.appending(path: "\(photo.id.uuidString).jpg")
            }
            try file.data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])
        }
    }

    private func replaceManagedFiles(with archive: BackupArchive, at applicationDirectory: URL) throws {
        let manager = FileManager.default
        for name in ["Photos", "Logos"] {
            let directory = applicationDirectory.appending(path: name)
            if manager.fileExists(atPath: directory.path()) {
                try manager.removeItem(at: directory)
            }
        }
        try stageFiles(for: archive, at: applicationDirectory)
    }

    private func replaceModels(with archive: BackupArchive, in context: ModelContext) throws {
        let preservedInvoices = try context.fetch(FetchDescriptor<InvoiceRecord>())
        let preservedCreditNotes = try context.fetch(FetchDescriptor<CreditNoteRecord>())
        let preservedNextInvoiceSequence = try context.fetch(FetchDescriptor<AppMetadata>())
            .compactMap(\.nextInvoiceSequence)
            .max() ?? 1
        let preservedNextCreditNoteSequence = try context.fetch(FetchDescriptor<AppMetadata>())
            .compactMap(\.nextCreditNoteSequence)
            .max() ?? 1
        try context.transaction {
            for model in try context.fetch(FetchDescriptor<WorkPackage>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<ProjectParty>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<ProjectTrade>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<JobPhoto>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<WorkEntry>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<MaterialEntry>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<PurchaseItem>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<ProductCatalogItem>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<Supplier>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<JobRecord>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<Customer>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<CompanyProfile>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<AppMetadata>()) { context.delete(model) }

            var customerByID: [UUID: Customer] = [:]
            for record in archive.customers {
                let customer = Customer(
                    id: record.id,
                    customerNumber: record.customerNumber,
                    name: record.name,
                    contactPerson: record.contactPerson,
                    phone: record.phone,
                    email: record.email,
                    address: record.address,
                    organizationNumber: record.organizationNumber,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    isSampleData: record.isSampleData ?? false
                )
                customerByID[record.id] = customer
                context.insert(customer)
            }

            var jobByID: [UUID: JobRecord] = [:]
            for record in archive.jobs {
                guard let customer = customerByID[record.customerID],
                      let status = JobStatus(rawValue: record.status) else {
                    throw BackupError.invalidReferences
                }
                let job = JobRecord(
                    id: record.id,
                    jobNumber: record.jobNumber,
                    title: record.title,
                    customer: customer,
                    workAddress: record.workAddress,
                    details: record.details,
                    plannedDate: record.plannedDate,
                    status: status,
                    completedAt: record.completedAt,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    isSampleData: record.isSampleData ?? false,
                    estimatedHours: record.estimatedHours,
                    hourlyRate: record.hourlyRate,
                    drivingKilometers: record.drivingKilometers,
                    drivingRatePerKilometer: record.drivingRatePerKilometer,
                    vatRatePercent: record.vatRatePercent,
                    hasInvoiceDraft: record.hasInvoiceDraft ?? false,
                    invoiceDraftDueDate: record.invoiceDraftDueDate,
                    archivedAt: record.archivedAt
                )
                job.projectMode = record.projectMode.flatMap(ProjectMode.init(rawValue:)) ?? .simpleJob
                jobByID[record.id] = job
                context.insert(job)
            }

            for record in archive.photos {
                guard let job = jobByID[record.jobID],
                      let category = PhotoCategory(rawValue: record.category) else {
                    throw BackupError.invalidReferences
                }
                context.insert(JobPhoto(
                    id: record.id,
                    relativePath: "Photos/\(record.jobID.uuidString)/\(record.id.uuidString).jpg",
                    category: category,
                    caption: record.caption,
                    registeredAt: record.registeredAt,
                    sortOrder: record.sortOrder,
                    job: job
                ))
            }

            for record in archive.workEntries {
                guard let job = jobByID[record.jobID] else { throw BackupError.invalidReferences }
                context.insert(WorkEntry(
                    id: record.id,
                    workDate: record.workDate,
                    details: record.details,
                    durationMinutes: record.durationMinutes,
                    drivingKilometers: record.drivingKilometers,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    job: job
                ))
            }

            for record in archive.materials {
                guard let job = jobByID[record.jobID] else { throw BackupError.invalidReferences }
                context.insert(MaterialEntry(
                    id: record.id,
                    name: record.name,
                    quantity: record.quantity,
                    unit: record.unit,
                    note: record.note,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    job: job,
                    unitPrice: record.unitPrice
                ))
            }

            for record in archive.purchaseItems ?? [] {
                guard let job = jobByID[record.jobID] else { throw BackupError.invalidReferences }
                context.insert(PurchaseItem(
                    id: record.id,
                    supplier: record.supplier,
                    itemName: record.itemName,
                    quantity: record.quantity,
                    unit: record.unit,
                    unitPrice: record.unitPrice,
                    note: record.note,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    transferredMaterialID: record.transferredMaterialID,
                    transferredAt: record.transferredAt,
                    job: job
                ))
            }

            var supplierByID: [UUID: Supplier] = [:]
            for record in archive.suppliers ?? [] {
                let supplier = Supplier(
                    id: record.id,
                    supplierNumber: record.supplierNumber,
                    name: record.name,
                    contactPerson: record.contactPerson,
                    phone: record.phone,
                    email: record.email,
                    address: record.address,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt
                )
                supplierByID[record.id] = supplier
                context.insert(supplier)
            }

            var tradeByID: [UUID: ProjectTrade] = [:]
            for record in archive.projectTrades ?? [] {
                guard let job = jobByID[record.jobID] else { throw BackupError.invalidReferences }
                let trade = ProjectTrade(id: record.id, code: record.code, name: record.name,
                                         isInternal: record.isInternal, plannedHours: record.plannedHours,
                                         createdAt: record.createdAt, updatedAt: record.updatedAt, job: job)
                tradeByID[record.id] = trade
                context.insert(trade)
            }

            var partyByID: [UUID: ProjectParty] = [:]
            for record in archive.projectParties ?? [] {
                guard let job = jobByID[record.jobID],
                      let role = ProjectPartyRole(rawValue: record.role) else {
                    throw BackupError.invalidReferences
                }
                let party = ProjectParty(id: record.id, role: role,
                                         contactPerson: record.contactPerson, note: record.note,
                                         createdAt: record.createdAt, updatedAt: record.updatedAt,
                                         job: job, supplier: record.supplierID.flatMap { supplierByID[$0] },
                                         trade: record.tradeID.flatMap { tradeByID[$0] })
                partyByID[record.id] = party
                context.insert(party)
            }

            for record in archive.workPackages ?? [] {
                guard let job = jobByID[record.jobID],
                      let status = WorkPackageStatus(rawValue: record.status) else {
                    throw BackupError.invalidReferences
                }
                context.insert(WorkPackage(id: record.id, packageNumber: record.packageNumber,
                                           title: record.title, details: record.details, status: status,
                                           plannedStart: record.plannedStart, plannedEnd: record.plannedEnd,
                                           progressPercent: record.progressPercent,
                                           budgetExcludingVAT: record.budgetExcludingVAT,
                                           plannedHours: record.plannedHours,
                                           materialBudgetIncludingVAT: record.materialBudgetIncludingVAT,
                                           laborBudgetIncludingVAT: record.laborBudgetIncludingVAT,
                                           createdAt: record.createdAt, updatedAt: record.updatedAt,
                                           job: job, trade: record.tradeID.flatMap { tradeByID[$0] },
                                           responsibleParty: record.responsiblePartyID.flatMap { partyByID[$0] }))
            }

            for record in archive.products ?? [] {
                context.insert(ProductCatalogItem(
                    id: record.id, itemNumber: record.itemNumber, supplier: record.supplier,
                    supplierRecord: record.supplierID.flatMap { supplierByID[$0] },
                    name: record.name, quantity: record.quantity ?? 1, unit: record.unit,
                    unitPrice: record.unitPrice, createdAt: record.createdAt, updatedAt: record.updatedAt
                ))
            }

            var invoiceIDs = Set(preservedInvoices.map(\.id))
            var invoiceNumbers = Set(preservedInvoices.map(\.invoiceNumber))
            for record in archive.invoices ?? [] {
                if invoiceIDs.contains(record.id) && invoiceNumbers.contains(record.invoiceNumber) {
                    continue
                }
                guard !invoiceIDs.contains(record.id), !invoiceNumbers.contains(record.invoiceNumber) else {
                    throw BackupError.duplicateIdentifier
                }
                context.insert(InvoiceRecord(
                    id: record.id, invoiceNumber: record.invoiceNumber, jobID: record.jobID,
                    jobNumber: record.jobNumber, issuedAt: record.issuedAt, dueDate: record.dueDate,
                    snapshotData: record.snapshotData
                ))
                invoiceIDs.insert(record.id)
                invoiceNumbers.insert(record.invoiceNumber)
            }

            var creditNoteIDs = Set(preservedCreditNotes.map(\.id))
            var creditNoteNumbers = Set(preservedCreditNotes.map(\.creditNoteNumber))
            var creditedInvoiceIDs = Set(preservedCreditNotes.map(\.originalInvoiceID))
            for record in archive.creditNotes ?? [] {
                if creditNoteIDs.contains(record.id)
                    && creditNoteNumbers.contains(record.creditNoteNumber)
                    && creditedInvoiceIDs.contains(record.originalInvoiceID) {
                    continue
                }
                guard !creditNoteIDs.contains(record.id),
                      !creditNoteNumbers.contains(record.creditNoteNumber),
                      !creditedInvoiceIDs.contains(record.originalInvoiceID) else {
                    throw BackupError.duplicateIdentifier
                }
                context.insert(CreditNoteRecord(
                    id: record.id,
                    creditNoteNumber: record.creditNoteNumber,
                    originalInvoiceID: record.originalInvoiceID,
                    originalInvoiceNumber: record.originalInvoiceNumber,
                    jobNumber: record.jobNumber,
                    issuedAt: record.issuedAt,
                    snapshotData: record.snapshotData
                ))
                creditNoteIDs.insert(record.id)
                creditNoteNumbers.insert(record.creditNoteNumber)
                creditedInvoiceIDs.insert(record.originalInvoiceID)
            }

            for record in archive.companies {
                context.insert(CompanyProfile(
                    id: record.id,
                    name: record.name,
                    organizationNumber: record.organizationNumber,
                    phone: record.phone,
                    email: record.email,
                    address: record.address,
                    bankAccount: record.bankAccount,
                    isVATRegistered: record.isVATRegistered ?? false,
                    isRegisteredInBusinessRegister: record.isRegisteredInBusinessRegister ?? false,
                    defaultHourlyRate: record.defaultHourlyRate,
                    defaultDrivingRatePerKilometer: record.defaultDrivingRatePerKilometer,
                    logoRelativePath: record.logoFileID == nil ? nil : "Logos/\(record.id.uuidString).image",
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt
                ))
            }
            let nextAfterKnownInvoices = invoiceNumbers.compactMap { number in
                number.split(separator: "-").last.flatMap { Int($0) }
            }.max().map { $0 + 1 } ?? 1
            let nextAfterKnownCreditNotes = creditNoteNumbers.compactMap { number in
                number.split(separator: "-").last.flatMap { Int($0) }
            }.max().map { $0 + 1 } ?? 1
            for record in archive.metadata {
                context.insert(AppMetadata(id: record.id, nextJobSequence: record.nextJobSequence,
                                           nextInvoiceSequence: max(
                                               record.nextInvoiceSequence ?? 1,
                                               preservedNextInvoiceSequence,
                                               nextAfterKnownInvoices
                                           ),
                                           nextCreditNoteSequence: max(
                                               record.nextCreditNoteSequence ?? 1,
                                               preservedNextCreditNoteSequence,
                                               nextAfterKnownCreditNotes
                                           )))
            }
            if archive.metadata.isEmpty {
                context.insert(AppMetadata(
                    nextInvoiceSequence: max(preservedNextInvoiceSequence, nextAfterKnownInvoices),
                    nextCreditNoteSequence: max(preservedNextCreditNoteSequence, nextAfterKnownCreditNotes)
                ))
            }
        }
    }

    private static func applicationDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appending(path: "JobbBevis", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

enum BackupError: LocalizedError {
    case invalidFormat
    case unsupportedVersion
    case archiveTooLarge
    case managedFileTooLarge
    case tooManyRecords
    case countMismatch
    case duplicateIdentifier
    case invalidReferences
    case invalidManagedFile
    case missingManagedFile
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat: String(localized: "This is not a valid JobbBevis backup.")
        case .unsupportedVersion: String(localized: "This backup version is not supported.")
        case .archiveTooLarge: String(localized: "The backup is too large.")
        case .managedFileTooLarge: String(localized: "A file in the backup is too large.")
        case .tooManyRecords: String(localized: "The backup contains too many records.")
        case .countMismatch: String(localized: "The backup manifest does not match its contents.")
        case .duplicateIdentifier: String(localized: "The backup contains duplicate identifiers.")
        case .invalidReferences: String(localized: "The backup contains invalid relationships.")
        case .invalidManagedFile: String(localized: "A file in the backup is missing or damaged.")
        case .missingManagedFile: String(localized: "A stored image is missing and the backup could not be created.")
        case .restoreFailed: String(localized: "The backup could not be restored. Existing data was preserved.")
        }
    }

    func description(locale: Locale) -> String {
        switch self {
        case .invalidFormat: String(localized: LocalizedStringResource("This is not a valid JobbBevis backup.", locale: locale))
        case .unsupportedVersion: String(localized: LocalizedStringResource("This backup version is not supported.", locale: locale))
        case .archiveTooLarge: String(localized: LocalizedStringResource("The backup is too large.", locale: locale))
        case .managedFileTooLarge: String(localized: LocalizedStringResource("A file in the backup is too large.", locale: locale))
        case .tooManyRecords: String(localized: LocalizedStringResource("The backup contains too many records.", locale: locale))
        case .countMismatch: String(localized: LocalizedStringResource("The backup manifest does not match its contents.", locale: locale))
        case .duplicateIdentifier: String(localized: LocalizedStringResource("The backup contains duplicate identifiers.", locale: locale))
        case .invalidReferences: String(localized: LocalizedStringResource("The backup contains invalid relationships.", locale: locale))
        case .invalidManagedFile: String(localized: LocalizedStringResource("A file in the backup is missing or damaged.", locale: locale))
        case .missingManagedFile: String(localized: LocalizedStringResource("A stored image is missing and the backup could not be created.", locale: locale))
        case .restoreFailed: String(localized: LocalizedStringResource("The backup could not be restored. Existing data was preserved.", locale: locale))
        }
    }
}

private struct BackupArchive: Codable {
    let manifest: BackupManifest
    let companies: [CompanyRecord]
    let customers: [CustomerRecord]
    let jobs: [JobRecordBackup]
    let photos: [PhotoRecord]
    let workEntries: [WorkRecord]
    let materials: [MaterialRecord]
    let purchaseItems: [PurchaseRecord]?
    let products: [ProductRecord]?
    let suppliers: [SupplierRecord]?
    let projectTrades: [ProjectTradeBackup]?
    let projectParties: [ProjectPartyBackup]?
    let workPackages: [WorkPackageBackup]?
    let invoices: [InvoiceBackupRecord]?
    let creditNotes: [CreditNoteBackupRecord]?
    let metadata: [MetadataRecord]
    let files: [BackupFile]
}

private struct BackupManifest: Codable {
    let format: String
    let schemaVersion: Int
    let createdAt: Date
    let appVersion: String
    let counts: BackupCounts
}

private struct BackupCounts: Codable, Equatable {
    let companies: Int
    let customers: Int
    let jobs: Int
    let photos: Int
    let workEntries: Int
    let materials: Int
    let purchases: Int?
    let products: Int?
    let invoices: Int?
    let creditNotes: Int?
    let files: Int
}

private struct CompanyRecord: Codable {
    let id: UUID
    let name: String
    let organizationNumber: String
    let phone: String
    let email: String
    let address: String
    let bankAccount: String?
    let isVATRegistered: Bool?
    let isRegisteredInBusinessRegister: Bool?
    let defaultHourlyRate: Decimal?
    let defaultDrivingRatePerKilometer: Decimal?
    let logoFileID: UUID?
    let createdAt: Date
    let updatedAt: Date
}

private struct CustomerRecord: Codable {
    let id: UUID
    let customerNumber: String?
    let name: String
    let contactPerson: String
    let phone: String
    let email: String
    let address: String
    let organizationNumber: String?
    let createdAt: Date
    let updatedAt: Date
    let isSampleData: Bool?
}

private struct JobRecordBackup: Codable {
    let id: UUID
    let customerID: UUID
    let jobNumber: String
    let title: String
    let workAddress: String
    let details: String
    let plannedDate: Date
    let status: String
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let isSampleData: Bool?
    let estimatedHours: Decimal?
    let hourlyRate: Decimal?
    let drivingKilometers: Decimal?
    let drivingRatePerKilometer: Decimal?
    let vatRatePercent: Decimal?
    let hasInvoiceDraft: Bool?
    let invoiceDraftDueDate: Date?
    let archivedAt: Date?
    let projectMode: String?
}

private struct ProjectTradeBackup: Codable {
    let id: UUID
    let jobID: UUID
    let code: String
    let name: String
    let isInternal: Bool
    let plannedHours: Decimal?
    let createdAt: Date
    let updatedAt: Date
}

private struct ProjectPartyBackup: Codable {
    let id: UUID
    let jobID: UUID
    let supplierID: UUID?
    let tradeID: UUID?
    let role: String
    let contactPerson: String
    let note: String
    let createdAt: Date
    let updatedAt: Date
}

private struct WorkPackageBackup: Codable {
    let id: UUID
    let jobID: UUID
    let tradeID: UUID?
    let responsiblePartyID: UUID?
    let packageNumber: String
    let title: String
    let details: String
    let status: String
    let plannedStart: Date?
    let plannedEnd: Date?
    let progressPercent: Int
    let budgetExcludingVAT: Decimal?
    let plannedHours: Decimal?
    let materialBudgetIncludingVAT: Decimal?
    let laborBudgetIncludingVAT: Decimal?
    let createdAt: Date
    let updatedAt: Date
}

private struct PhotoRecord: Codable {
    let id: UUID
    let jobID: UUID
    let fileID: UUID
    let category: String
    let caption: String
    let registeredAt: Date
    let sortOrder: Int
}

private struct WorkRecord: Codable {
    let id: UUID
    let jobID: UUID
    let workDate: Date
    let details: String
    let durationMinutes: Int
    let drivingKilometers: Decimal?
    let createdAt: Date
    let updatedAt: Date
}

private struct MaterialRecord: Codable {
    let id: UUID
    let jobID: UUID
    let name: String
    let quantity: Decimal
    let unit: String
    let note: String
    let createdAt: Date
    let updatedAt: Date
    let unitPrice: Decimal?
}

private struct PurchaseRecord: Codable {
    let id: UUID
    let jobID: UUID
    let supplier: String
    let itemName: String
    let quantity: Decimal
    let unit: String
    let unitPrice: Decimal
    let note: String
    let createdAt: Date
    let updatedAt: Date
    let transferredMaterialID: UUID?
    let transferredAt: Date?
}

private struct MetadataRecord: Codable {
    let id: String
    let nextJobSequence: Int
    let nextInvoiceSequence: Int?
    let nextCreditNoteSequence: Int?
}

private struct ProductRecord: Codable {
    let id: UUID
    let itemNumber: String?
    let supplier: String
    let supplierID: UUID?
    let name: String
    let unit: String
    let quantity: Decimal?
    let unitPrice: Decimal
    let createdAt: Date
    let updatedAt: Date
}

private struct SupplierRecord: Codable {
    let id: UUID
    let supplierNumber: String
    let name: String
    let contactPerson: String
    let phone: String
    let email: String
    let address: String
    let createdAt: Date
    let updatedAt: Date
}

private struct InvoiceBackupRecord: Codable {
    let id: UUID
    let invoiceNumber: String
    let jobID: UUID
    let jobNumber: String
    let issuedAt: Date
    let dueDate: Date
    let snapshotData: Data
}

private struct CreditNoteBackupRecord: Codable {
    let id: UUID
    let creditNoteNumber: String
    let originalInvoiceID: UUID
    let originalInvoiceNumber: String
    let jobNumber: String
    let issuedAt: Date
    let snapshotData: Data
}

private struct BackupFile: Codable {
    enum Kind: String, Codable {
        case logo
        case photo
    }

    let id: UUID
    let kind: Kind
    let ownerID: UUID
    let archivePath: String
    let byteCount: Int
    let sha256: String
    let data: Data
}
