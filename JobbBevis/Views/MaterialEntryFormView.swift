import SwiftData
import SwiftUI

struct MaterialEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let job: JobRecord
    let entry: MaterialEntry?

    @State private var name: String
    @State private var quantityText: String
    @State private var selectedUnit: String
    @State private var customUnit: String
    @State private var note: String
    @State private var showNameError = false
    @State private var showQuantityError = false
    @State private var showUnitError = false
    @State private var errorMessage: String?

    init(job: JobRecord, entry: MaterialEntry? = nil) {
        self.job = job
        self.entry = entry
        let existingUnit = entry?.unit ?? MaterialUnit.pieces.rawValue
        let isPreset = MaterialUnit.allCases.contains { $0.rawValue == existingUnit }
        _name = State(initialValue: entry?.name ?? "")
        _quantityText = State(initialValue: entry.map { String(describing: $0.quantity) } ?? "")
        _selectedUnit = State(initialValue: isPreset ? existingUnit : "custom")
        _customUnit = State(initialValue: isPreset ? "" : existingUnit)
        _note = State(initialValue: entry?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Material") {
                    TextField("Name", text: $name)
                    if showNameError {
                        Text("Enter a material name.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Quantity", text: $quantityText)
                        .keyboardType(.decimalPad)
                    if showQuantityError {
                        Text("Enter a quantity greater than zero using the local decimal separator.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(MaterialUnit.allCases) { unit in
                            Text(unit.title).tag(unit.rawValue)
                        }
                        Text("Custom unit").tag("custom")
                    }

                    if selectedUnit == "custom" {
                        TextField("Unit", text: $customUnit)
                    }
                    if showUnitError {
                        Text("Enter a unit.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(entry == nil ? "New material" : "Edit material")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear {
                if let entry {
                    quantityText = EntryFormatting.formatDecimal(entry.quantity, locale: locale)
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantity = EntryFormatting.parseDecimal(quantityText, locale: locale)
        let resolvedUnit = selectedUnit == "custom"
            ? customUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            : selectedUnit

        showNameError = trimmedName.isEmpty
        showQuantityError = quantity == nil || quantity.map { $0 <= 0 } == true
        showUnitError = resolvedUnit.isEmpty
        guard !trimmedName.isEmpty,
              let quantity,
              quantity > 0,
              !resolvedUnit.isEmpty else {
            return
        }

        let savedEntry: MaterialEntry
        if let entry {
            savedEntry = entry
        } else {
            savedEntry = MaterialEntry(
                name: trimmedName,
                quantity: quantity,
                unit: resolvedUnit,
                job: job
            )
            modelContext.insert(savedEntry)
            job.materialEntries.append(savedEntry)
        }

        savedEntry.name = trimmedName
        savedEntry.quantity = quantity
        savedEntry.unit = resolvedUnit
        savedEntry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        savedEntry.updatedAt = .now
        job.updatedAt = .now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The material could not be saved. Try again.")
        }
    }
}
