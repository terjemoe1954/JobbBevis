import SwiftData
import SwiftUI

struct MaterialEntriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let job: JobRecord
    @State private var selectedEntry: MaterialEntry?
    @State private var isAddingEntry = false
    @State private var entryPendingDeletion: MaterialEntry?
    @State private var errorMessage: String?

    private var orderedEntries: [MaterialEntry] {
        job.materialEntries.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if orderedEntries.isEmpty {
                MaterialEmptyState(addEntry: { isAddingEntry = true })
            } else {
                List(orderedEntries) { entry in
                    Button {
                        selectedEntry = entry
                    } label: {
                        MaterialEntryRow(entry: entry, locale: locale)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            entryPendingDeletion = entry
                        }
                    }
                }
            }
        }
        .navigationTitle("Materials")
        .toolbar {
            Button("Add material", systemImage: "plus") {
                isAddingEntry = true
            }
        }
        .sheet(isPresented: $isAddingEntry) {
            MaterialEntryFormView(job: job)
        }
        .sheet(item: $selectedEntry) { entry in
            MaterialEntryFormView(job: job, entry: entry)
        }
        .confirmationDialog(
            "Delete material?",
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deletePendingEntry)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Could not delete material", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { entryPendingDeletion != nil },
            set: { if !$0 { entryPendingDeletion = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func deletePendingEntry() {
        guard let entryPendingDeletion else { return }
        modelContext.delete(entryPendingDeletion)
        job.updatedAt = .now
        do {
            try modelContext.save()
            self.entryPendingDeletion = nil
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The material could not be deleted. Try again.")
        }
    }
}

private struct MaterialEntryRow: View {
    let entry: MaterialEntry
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.headline)
                Spacer()
                MaterialQuantityView(
                    quantity: EntryFormatting.formatDecimal(entry.quantity, locale: locale),
                    unit: entry.unit
                )
            }
            if !entry.note.isEmpty {
                Text(entry.note)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct MaterialQuantityView: View {
    let quantity: String
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            Text(quantity)
            if let predefinedUnit = MaterialUnit(rawValue: unit) {
                Text(predefinedUnit.title)
            } else {
                Text(unit)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct MaterialEmptyState: View {
    let addEntry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No materials", systemImage: "shippingbox")
        } description: {
            Text("Add materials used for this job. Prices are not included.")
        } actions: {
            Button("Add material", systemImage: "plus", action: addEntry)
        }
    }
}
