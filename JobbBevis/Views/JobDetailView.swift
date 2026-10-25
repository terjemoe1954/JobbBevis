import SwiftData
import SwiftUI

struct JobDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    @State private var isEditing = false
    @State private var isCreatingReport = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            JobOverviewSection(job: job)
            JobDescriptionSection(details: job.details)
            JobDocumentationSection(job: job)
            Section {
                Button("Create report", systemImage: "doc.richtext") {
                    isCreatingReport = true
                }
            }
        }
        .navigationTitle(job.jobNumber)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") {
                    isEditing = true
                }
                Button("Delete job", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            JobFormView(job: job)
        }
        .sheet(isPresented: $isCreatingReport) {
            ReportBuilderView(job: job)
        }
        .confirmationDialog(
            "Delete job?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteJob)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All entries and files belonging to this job will also be deleted. This cannot be undone.")
        }
        .alert("Could not delete job", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func deleteJob() {
        do {
            var stagedRemovals: [StagedPhotoRemoval] = []
            do {
                for path in job.photos.map(\.relativePath) {
                    stagedRemovals.append(try PhotoFileStore().stageRemoval(relativePath: path))
                }
            } catch {
                for removal in stagedRemovals {
                    try? removal.restore()
                }
                throw error
            }
            modelContext.delete(job)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                for removal in stagedRemovals {
                    try? removal.restore()
                }
                throw error
            }
            for removal in stagedRemovals {
                try removal.commit()
            }
            dismiss()
        } catch {
            errorMessage = String(localized: "The job could not be deleted. \(error.localizedDescription)")
        }
    }
}

private struct JobDocumentationSection: View {
    let job: JobRecord

    private var totalMinutes: Int {
        job.workEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        Section("Documentation") {
            NavigationLink {
                JobPhotosView(job: job)
            } label: {
                DocumentationLinkLabel(
                    title: "Photos",
                    systemImage: "photo.on.rectangle.angled",
                    value: "\(job.photos.count)"
                )
            }
            NavigationLink {
                WorkEntriesView(job: job)
            } label: {
                DocumentationLinkLabel(
                    title: "Work log",
                    systemImage: "clock",
                    value: EntryFormatting.duration(totalMinutes: totalMinutes)
                )
            }
            NavigationLink {
                MaterialEntriesView(job: job)
            } label: {
                DocumentationLinkLabel(
                    title: "Materials",
                    systemImage: "shippingbox",
                    value: "\(job.materialEntries.count)"
                )
            }
        }
    }
}

private struct DocumentationLinkLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    let value: String

    var body: some View {
        Label(title, systemImage: systemImage)
        Spacer()
        Text(value)
            .foregroundStyle(.secondary)
    }
}

private struct JobOverviewSection: View {
    let job: JobRecord

    var body: some View {
        Section("Overview") {
            LabeledContent("Title", value: job.title)
            LabeledContent("Customer", value: job.customer.name)
            LabeledContent("Status") {
                Text(job.status.title)
            }
            LabeledContent("Planned date") {
                Text(job.plannedDate, format: .dateTime.day().month().year())
            }
            if let completedAt = job.completedAt {
                LabeledContent("Completed date") {
                    Text(completedAt, format: .dateTime.day().month().year())
                }
            }
            if !job.workAddress.isEmpty {
                LabeledContent("Work address", value: job.workAddress)
            }
        }
    }
}

private struct JobDescriptionSection: View {
    let details: String

    var body: some View {
        Section("Description") {
            if details.isEmpty {
                Text("No description has been added.")
                    .foregroundStyle(.secondary)
            } else {
                Text(details)
            }
        }
    }
}

struct JobRowView: View {
    let job: JobRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.title)
                    .font(.headline)
                Spacer()
                Text(job.status.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(job.jobNumber)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(job.customer.name)
                .font(.subheadline)
            Text(job.plannedDate, format: .dateTime.day().month().year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
