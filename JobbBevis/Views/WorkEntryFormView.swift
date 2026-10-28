import SwiftData
import SwiftUI

struct WorkEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let job: JobRecord
    let entry: WorkEntry?

    @State private var workDate: Date
    @State private var details: String
    @State private var hours: Int
    @State private var minutes: Int
    @State private var drivingKilometersText: String
    @State private var showDescriptionError = false
    @State private var showDurationError = false
    @State private var errorMessage: String?

    init(job: JobRecord, entry: WorkEntry? = nil) {
        self.job = job
        self.entry = entry
        _workDate = State(initialValue: entry?.workDate ?? .now)
        _details = State(initialValue: entry?.details ?? "")
        _hours = State(initialValue: (entry?.durationMinutes ?? 0) / 60)
        _minutes = State(initialValue: (entry?.durationMinutes ?? 0) % 60)
        _drivingKilometersText = State(initialValue: entry?.drivingKilometers.map(String.init(describing:)) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Work") {
                    DatePicker("Work date", selection: $workDate, displayedComponents: .date)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                    if showDescriptionError {
                        Text("Enter a description of the work.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Time spent") {
                    Stepper(value: $hours, in: 0...999) {
                        LabeledContent("Hours", value: "\(hours)")
                    }
                    Stepper(value: $minutes, in: 0...59) {
                        LabeledContent("Minutes", value: "\(minutes)")
                    }
                    Text("Duration: \(EntryFormatting.duration(hours: hours, minutes: minutes))")
                        .foregroundStyle(.secondary)
                    if showDurationError {
                        Text("Enter a duration greater than zero.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Driving") {
                    TextField("Driven kilometers", text: $drivingKilometersText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(entry == nil ? "New work entry" : "Edit work entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .alert("Could not save changes", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func save() {
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationMinutes = hours * 60 + minutes
        let kilometersText = drivingKilometersText.trimmingCharacters(in: .whitespacesAndNewlines)
        let drivingKilometers = kilometersText.isEmpty
            ? nil
            : EntryFormatting.parseDecimal(kilometersText, locale: locale)
        showDescriptionError = trimmedDetails.isEmpty
        showDurationError = durationMinutes <= 0
        guard !trimmedDetails.isEmpty, durationMinutes > 0,
              kilometersText.isEmpty || drivingKilometers.map({ $0 >= 0 }) == true else {
            if !kilometersText.isEmpty {
                errorMessage = String(localized: "Enter valid driven kilometers.")
            }
            return
        }

        let savedEntry: WorkEntry
        if let entry {
            savedEntry = entry
        } else {
            savedEntry = WorkEntry(
                workDate: workDate,
                details: trimmedDetails,
                durationMinutes: durationMinutes,
                job: job
            )
            modelContext.insert(savedEntry)
            job.workEntries.append(savedEntry)
        }

        savedEntry.workDate = workDate
        savedEntry.details = trimmedDetails
        savedEntry.durationMinutes = durationMinutes
        savedEntry.drivingKilometers = drivingKilometers
        savedEntry.updatedAt = .now
        job.updatedAt = .now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The work entry could not be saved. Try again.")
        }
    }
}
