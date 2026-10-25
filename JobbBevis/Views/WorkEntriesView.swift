import SwiftData
import SwiftUI

struct WorkEntriesView: View {
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    @State private var selectedEntry: WorkEntry?
    @State private var isAddingEntry = false
    @State private var entryPendingDeletion: WorkEntry?
    @State private var errorMessage: String?

    private var orderedEntries: [WorkEntry] {
        job.workEntries.sorted { $0.workDate > $1.workDate }
    }

    private var totalMinutes: Int {
        job.workEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        Group {
            if orderedEntries.isEmpty {
                WorkEmptyState(addEntry: { isAddingEntry = true })
            } else {
                List {
                    Section {
                        ForEach(orderedEntries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                WorkEntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    entryPendingDeletion = entry
                                }
                            }
                        }
                    } footer: {
                        Text("Total time: \(EntryFormatting.duration(totalMinutes: totalMinutes))")
                    }
                }
            }
        }
        .navigationTitle("Work log")
        .toolbar {
            Button("Add work entry", systemImage: "plus") {
                isAddingEntry = true
            }
        }
        .sheet(isPresented: $isAddingEntry) {
            WorkEntryFormView(job: job)
        }
        .sheet(item: $selectedEntry) { entry in
            WorkEntryFormView(job: job, entry: entry)
        }
        .confirmationDialog(
            "Delete work entry?",
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deletePendingEntry)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Could not delete work entry", isPresented: errorBinding) {
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
            errorMessage = String(localized: "The work entry could not be deleted. Try again.")
        }
    }
}

private struct WorkEntryRow: View {
    let entry: WorkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.workDate, format: .dateTime.day().month().year())
                    .font(.headline)
                Spacer()
                Text(EntryFormatting.duration(totalMinutes: entry.durationMinutes))
                    .foregroundStyle(.secondary)
            }
            Text(entry.details)
                .lineLimit(2)
        }
        .contentShape(Rectangle())
    }
}

private struct WorkEmptyState: View {
    let addEntry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No work entries", systemImage: "clock")
        } description: {
            Text("Add a work date, description, and time spent.")
        } actions: {
            Button("Add work entry", systemImage: "plus", action: addEntry)
        }
    }
}
