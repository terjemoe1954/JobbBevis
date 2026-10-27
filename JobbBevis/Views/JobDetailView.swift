import SwiftData
import SwiftUI

struct JobDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var invoices: [InvoiceRecord]
    let job: JobRecord
    @State private var isEditing = false
    @State private var isCreatingReport = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showArchiveConfirmation = false

    var body: some View {
        List {
            JobOverviewSection(job: job)
            JobDescriptionSection(details: job.details)
            JobDocumentationSection(job: job)
            JobPriceEstimateSummary(job: job)
            Section {
                Button("Create report", systemImage: "doc.richtext") {
                    isCreatingReport = true
                }
                NavigationLink {
                    SalesDocumentsView(job: job, workflow: .orderConfirmation)
                } label: {
                    Label("Order confirmation", systemImage: "doc.text.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
        .appListAppearance()
        .navigationTitle(job.jobNumber)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if job.isArchived {
                    Button("Restore job", systemImage: "arrow.uturn.backward", action: restoreJob)
                } else {
                    Button("Edit", systemImage: "pencil") {
                        isEditing = true
                    }
                    if hasInvoice {
                        Button("Archive job", systemImage: "archivebox") {
                            showArchiveConfirmation = true
                        }
                    } else {
                        Button("Delete job", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
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
        .confirmationDialog(
            "Archive invoiced job?",
            isPresented: $showArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive job", action: archiveJob)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The job is hidden from active lists. Its invoices, credit notes, entries, and files are kept.")
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

    private var hasInvoice: Bool {
        invoices.contains { $0.jobID == job.id }
    }

    private func deleteJob() {
        guard !hasInvoice else {
            errorMessage = String(localized: "Invoiced jobs cannot be deleted. Archive the job instead.")
            return
        }
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

    private func archiveJob() {
        job.archivedAt = .now
        job.updatedAt = .now
        saveArchiveChange()
    }

    private func restoreJob() {
        job.archivedAt = nil
        job.updatedAt = .now
        saveArchiveChange()
    }

    private func saveArchiveChange() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The job archive status could not be saved. Try again.")
        }
    }
}

private struct JobPriceEstimateSummary: View {
    @Environment(\.locale) private var locale
    let job: JobRecord

    private var hasEstimate: Bool {
        job.estimatedHours != nil
            || job.hourlyRate != nil
            || job.drivingKilometers != nil
            || job.drivingRatePerKilometer != nil
            || job.materialEntries.contains { $0.unitPrice != nil }
    }

    var body: some View {
        if hasEstimate {
            let estimate = PriceEstimateCalculator.estimate(for: job)
            Section("Price estimate") {
                LabeledContent("Labor", value: PriceEstimateCalculator.currency(estimate.labor, locale: locale))
                LabeledContent("Materials", value: PriceEstimateCalculator.currency(estimate.materials, locale: locale))
                LabeledContent("Driving", value: PriceEstimateCalculator.currency(estimate.driving, locale: locale))
                LabeledContent("Subtotal excluding VAT", value: PriceEstimateCalculator.currency(estimate.subtotal, locale: locale))
                if job.vatRatePercent != nil {
                    LabeledContent("VAT", value: PriceEstimateCalculator.currency(estimate.vat, locale: locale))
                }
                LabeledContent("Suggested total price", value: PriceEstimateCalculator.currency(estimate.total, locale: locale))
                    .font(.headline)
            }
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
            NavigationLink {
                PurchaseListView(job: job)
            } label: {
                DocumentationLinkLabel(
                    title: "Purchase list",
                    systemImage: "cart",
                    value: "\(job.purchaseItems.count)"
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
        Label {
            Text(title)
        } icon: {
            FeatureIcon(systemImage: systemImage, color: .blue)
        }
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
                Text(job.isArchived ? LocalizedStringResource("Archived") : job.status.title)
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
        HStack(alignment: .top, spacing: 12) {
            FeatureIcon(
                systemImage: job.status == .completed ? "checkmark.circle.fill" : "hammer.fill",
                color: AppTheme.statusColor(job.status)
            )
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(job.title)
                        .font(.headline)
                    Spacer()
                    StatusBadge(status: job.status)
                }
                Text(job.jobNumber)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
                Text(job.customer.name)
                    .font(.subheadline)
                Label {
                    Text(job.plannedDate, format: .dateTime.day().month().year())
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
