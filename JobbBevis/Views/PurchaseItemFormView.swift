import SwiftData
import SwiftUI

struct PurchaseItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    let item: PurchaseItem?

    @State private var supplier: String
    @State private var itemName: String
    @State private var quantityText: String
    @State private var selectedUnit: String
    @State private var customUnit: String
    @State private var unitPriceText: String
    @State private var note: String
    @State private var validationMessage: String?
    @State private var errorMessage: String?

    init(job: JobRecord, item: PurchaseItem? = nil) {
        self.job = job
        self.item = item
        let existingUnit = item?.unit ?? MaterialUnit.pieces.rawValue
        let isPreset = MaterialUnit.allCases.contains { $0.rawValue == existingUnit }
        _supplier = State(initialValue: item?.supplier ?? "")
        _itemName = State(initialValue: item?.itemName ?? "")
        _quantityText = State(initialValue: item?.quantity.description ?? "")
        _selectedUnit = State(initialValue: isPreset ? existingUnit : "custom")
        _customUnit = State(initialValue: isPreset ? "" : existingUnit)
        _unitPriceText = State(initialValue: item?.unitPrice.description ?? "")
        _note = State(initialValue: item?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase item") {
                    TextField("Supplier", text: $supplier)
                    TextField("Item", text: $itemName)
                    TextField("Quantity", text: $quantityText)
                        .keyboardType(.decimalPad)

                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(MaterialUnit.allCases) { unit in
                            Text(unit.title).tag(unit.rawValue)
                        }
                        Text("Custom unit").tag("custom")
                    }
                    if selectedUnit == "custom" {
                        TextField("Unit", text: $customUnit)
                    }

                    TextField("Unit price, excluding VAT", text: $unitPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...5)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(item == nil ? "New purchase item" : "Edit purchase item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear(perform: formatExistingValues)
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

    private func formatExistingValues() {
        guard let item else { return }
        quantityText = EntryFormatting.formatDecimal(item.quantity, locale: locale)
        unitPriceText = EntryFormatting.formatDecimal(item.unitPrice, locale: locale)
    }

    private func save() {
        let trimmedSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUnit = selectedUnit == "custom"
            ? customUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            : selectedUnit
        let quantity = EntryFormatting.parseDecimal(quantityText, locale: locale)
        let unitPrice = EntryFormatting.parseDecimal(unitPriceText, locale: locale)

        guard !trimmedSupplier.isEmpty,
              !trimmedName.isEmpty,
              !resolvedUnit.isEmpty,
              let quantity,
              quantity > 0,
              let unitPrice,
              unitPrice >= 0 else {
            validationMessage = String(
                localized: "Enter supplier, item, positive quantity, unit, and a valid unit price."
            )
            return
        }

        let savedItem: PurchaseItem
        if let item {
            savedItem = item
        } else {
            savedItem = PurchaseItem(
                supplier: trimmedSupplier,
                itemName: trimmedName,
                quantity: quantity,
                unit: resolvedUnit,
                unitPrice: unitPrice,
                job: job
            )
            modelContext.insert(savedItem)
            job.purchaseItems.append(savedItem)
        }

        savedItem.supplier = trimmedSupplier
        savedItem.itemName = trimmedName
        savedItem.quantity = quantity
        savedItem.unit = resolvedUnit
        savedItem.unitPrice = unitPrice
        savedItem.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        savedItem.updatedAt = .now
        job.updatedAt = .now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The purchase item could not be saved. Try again.")
        }
    }
}
