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
    @State private var restoreCandidate: RestoreCandidate?
    @State private var message: BackupMessage?

    var body: some View {
        Group {
            Section("Backup") {
                Button("Export backup", systemImage: "square.and.arrow.up", action: prepareExport)
                Button("Restore backup", systemImage: "arrow.down.doc", action: { isImporting = true })

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

            if let restoreCandidate {
                RestoreConfirmationSection(
                    summary: restoreCandidate.prepared.summary,
                    exportCurrent: prepareExportBeforeRestore,
                    restore: { performRestore(restoreCandidate) },
                    cancel: cancelRestore
                )
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
        .alert(item: $message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.text),
                dismissButton: .default(Text("OK"))
            )
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
        restoreCandidate = nil
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
                restoreCandidate = RestoreCandidate(prepared: prepared)
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

    private func performRestore(_ restoreCandidate: RestoreCandidate) {
        do {
            try BackupService().restore(restoreCandidate.prepared, into: modelContext)
            self.restoreCandidate = nil
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                message = BackupMessage(
                    title: String(localized: LocalizedStringResource("Backup restored", locale: locale)),
                    text: String(localized: LocalizedStringResource("The existing data was replaced with the backup.", locale: locale))
                )
            }
        } catch {
            self.restoreCandidate = nil
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                message = BackupMessage(
                    title: String(localized: LocalizedStringResource("Could not restore backup", locale: locale)),
                    text: localizedError(error)
                )
            }
        }
    }

    private func cancelRestore() {
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
}

private struct BackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

private struct RestoreConfirmationSection: View {
    @Environment(\.locale) private var locale
    @State private var isRestoring = false
    let summary: BackupSummary
    let exportCurrent: () -> Void
    let restore: () -> Void
    let cancel: () -> Void

    var body: some View {
        Section("Restore backup") {
            LabeledContent("Customers", value: summary.customers.formatted())
            LabeledContent("Jobs", value: summary.jobs.formatted())
            LabeledContent("Photos", value: summary.photos.formatted())
            LabeledContent("Work entries", value: summary.workEntries.formatted())
            LabeledContent("Materials", value: summary.materials.formatted())
            LabeledContent(
                "Created",
                value: summary.createdAt.formatted(
                    .dateTime.day().month(.abbreviated).year().hour().minute().locale(locale)
                )
            )

            Text("Restoring uses full replacement. All current customers, jobs, work entries, materials, company information, logo, and images will be replaced.")
                .foregroundStyle(.secondary)

            Button("Export current data first", systemImage: "square.and.arrow.up", action: exportCurrent)
            Button(role: .destructive, action: beginRestore) {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Replace current data")
                }
            }
            .disabled(isRestoring)

            Button("Cancel", role: .cancel, action: cancel)
                .disabled(isRestoring)
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
