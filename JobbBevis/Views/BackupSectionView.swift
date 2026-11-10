import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupTransferItem: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { item in
            item.data
        }
    }
}

struct BackupSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @State private var exportItem: BackupTransferItem?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isReadingBackup = false
    @State private var importMode: BackupImportMode = .full
    @State private var showsConfirmation = false
    @State private var exportsAfterConfirmationDismisses = false
    @State private var restoreCandidate: RestoreCandidate?
    @State private var message: BackupMessage?

    var body: some View {
        Form {
            if let message {
                Section {
                    Text(message.title).font(.headline)
                    Text(message.text)
                }
            }
            if let candidate = restoreCandidate {
                Section("Selected backup") {
                    LabeledContent("Customers", value: candidate.prepared.summary.customers.formatted())
                    LabeledContent("Suppliers", value: candidate.prepared.summary.suppliers.formatted())
                    LabeledContent("Products", value: candidate.prepared.summary.products.formatted())
                    Text(candidate.mode.title)
                    Button("Review selected backup") { showsConfirmation = true }
                    Button("Cancel", role: .cancel, action: cancelRestore)
                }
            }
            Section("Backup") {
                Button("Export backup", systemImage: "square.and.arrow.up", action: prepareExport)
                Picker("Import contents", selection: $importMode) {
                    ForEach(BackupImportMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(importMode == .full
                    ? LocalizedStringResource("Restore all backup contents. Existing issued invoices and credit notes are retained.")
                    : LocalizedStringResource("Import customers, suppliers and products only. Current jobs and their photos, work and drafts are removed. Company details, number sequences and issued documents on this device are retained."))
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Choose backup file", systemImage: "arrow.down.doc", action: { restoreCandidate = nil; message = nil; isImporting = true })

                if isReadingBackup {
                    HStack {
                        ProgressView()
                        Text("Reading backup…")
                    }
                }

                Text("A backup contains customer information and images. Store it safely. The file is not encrypted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        }
        .navigationTitle("Backup")
        .sheet(isPresented: $showsConfirmation, onDismiss: confirmationDidDismiss) {
            if let candidate = restoreCandidate {
                RestoreConfirmationSection(
                    summary: candidate.prepared.summary,
                    mode: candidate.mode,
                    exportCurrent: prepareExportBeforeRestore,
                    restore: { performRestore(candidate) },
                    cancel: cancelRestore
                )
                .interactiveDismissDisabled()
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            item: exportItem,
            contentTypes: [.json],
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success:
                message = BackupMessage(
                    title: String(localized: LocalizedStringResource("Backup exported", locale: locale)),
                    text: String(localized: LocalizedStringResource("The backup was exported successfully.", locale: locale))
                )
            case .failure(let error):
                message = BackupMessage(
                    title: String(localized: LocalizedStringResource("Could not export backup", locale: locale)),
                    text: localizedError(error)
                )
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result.map { $0.first })
        }
    }

    private func confirmationDidDismiss() {
        if exportsAfterConfirmationDismisses {
            exportsAfterConfirmationDismisses = false
            isExporting = true
        }
    }

    private var defaultFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "JobbBevis-Backup-\(date)"
    }

    private func prepareExport() {
        do {
            exportItem = BackupTransferItem(data: try BackupService().exportData(from: modelContext))
            isExporting = true
        } catch {
            message = BackupMessage(
                title: String(localized: LocalizedStringResource("Could not export backup", locale: locale)),
                text: localizedError(error)
            )
        }
    }

    private func prepareExportBeforeRestore() {
        do {
            exportItem = BackupTransferItem(data: try BackupService().exportData(from: modelContext))
            exportsAfterConfirmationDismisses = true
            showsConfirmation = false
        } catch {
            showsConfirmation = false
            message = BackupMessage(
                title: String(localized: LocalizedStringResource("Could not export backup", locale: locale)),
                text: localizedError(error)
            )
        }
    }

    private func handleImportResult(_ result: Result<URL?, Error>) {
        switch result {
        case .success(let url?):
            let didAccess = url.startAccessingSecurityScopedResource()
            isReadingBackup = true
            defer {
                isReadingBackup = false
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // File providers may vend a temporary URL that is only guaranteed to
                // remain valid while handling the import result. Read it before this
                // callback returns, then work exclusively with the in-memory copy.
                let data = try readImportedData(from: url)
                let prepared = try BackupService().prepareImport(data: data)
                restoreCandidate = RestoreCandidate(prepared: prepared, mode: importMode)
            } catch {
                showImportError(error)
            }
        case .success(nil):
            showImportError(BackupError.invalidFormat)
        case .failure(let error):
            showImportError(error)
        }
    }

    private func showImportError(_ error: Error) {
        message = BackupMessage(
            title: String(localized: LocalizedStringResource("Could not read backup", locale: locale)),
            text: localizedError(error)
        )
    }

    private func performRestore(_ candidate: RestoreCandidate) {
        do {
            try BackupService().restore(candidate.prepared, mode: candidate.mode, into: modelContext)
            restoreCandidate = nil
            message = BackupMessage(
                title: String(localized: LocalizedStringResource("Backup restored", locale: locale)),
                text: String(localized: LocalizedStringResource(candidate.mode == .full
                    ? "The existing data was replaced with the backup."
                    : "Customers, suppliers and products were imported. Current jobs were removed; company details, number sequences and issued documents were retained.", locale: locale))
            )
        } catch {
            message = BackupMessage(
                title: String(localized: LocalizedStringResource("Could not restore backup", locale: locale)),
                text: localizedError(error)
            )
        }
        showsConfirmation = false
    }

    private func cancelRestore() {
        showsConfirmation = false
        restoreCandidate = nil
    }

    private func localizedError(_ error: Error) -> String {
        if let backupError = error as? BackupError {
            return backupError.description(locale: locale)
        }
        return error.localizedDescription
    }

    private func readImportedData(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?
        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            readResult = Result {
                // Some document providers expose a readable file representation
                // without supporting path-based FileManager metadata queries.
                let data = try Data(contentsOf: coordinatedURL)
                if data.count > BackupService.maximumArchiveBytes {
                    throw BackupError.archiveTooLarge
                }
                return data
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let readResult else {
            throw BackupError.invalidFormat
        }
        return try readResult.get()
    }
}

private struct RestoreCandidate: Identifiable {
    let id = UUID()
    let prepared: PreparedBackup
    let mode: BackupImportMode
}

private struct BackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

private struct RestoreConfirmationSection: View {
    @Environment(\.locale) private var locale
    @State private var isRestoring = false
    @State private var confirmsReplacement = false
    let summary: BackupSummary
    let mode: BackupImportMode
    let exportCurrent: () -> Void
    let restore: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Before importing") {
                    Text(mode == .full
                        ? LocalizedStringResource("Current editable data, company details and images will be replaced. Existing issued invoices and credit notes are retained.")
                        : LocalizedStringResource("Import customers, suppliers and products only. Current jobs and their photos, work and drafts are removed. Company details, number sequences and issued documents on this device are retained."))
                    Button("Export current data first", systemImage: "square.and.arrow.up", action: exportCurrent)
                    Toggle("I understand that current data will be replaced", isOn: $confirmsReplacement)
                }
                Section("Contents to import") {
                    LabeledContent("Customers", value: summary.customers.formatted())
                    LabeledContent("Suppliers", value: summary.suppliers.formatted())
                    LabeledContent("Products", value: summary.products.formatted())
                    if mode == .full {
                        LabeledContent("Jobs", value: summary.jobs.formatted())
                        LabeledContent("Photos", value: summary.photos.formatted())
                        LabeledContent("Work entries", value: summary.workEntries.formatted())
                        LabeledContent("Materials", value: summary.materials.formatted())
                    }
                    LabeledContent("Created", value: summary.createdAt.formatted(
                        .dateTime.day().month(.abbreviated).year().hour().minute().locale(locale)))
                }
            }
            .disabled(isRestoring)
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel).disabled(isRestoring)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive, action: beginRestore) {
                        if isRestoring { ProgressView() } else { Text("Replace and import") }
                    }
                    .disabled(!confirmsReplacement || isRestoring)
                }
            }
        }
    }

    private func beginRestore() {
        isRestoring = true
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            restore()
        }
    }
}
