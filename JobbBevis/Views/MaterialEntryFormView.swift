import SwiftData
import SwiftUI

struct MaterialEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: [SortDescriptor(\ProductCatalogItem.itemNumber), SortDescriptor(\ProductCatalogItem.name)])
    private var products: [ProductCatalogItem]
    let job: JobRecord
    let entry: MaterialEntry?

    @State private var name: String
    @State private var quantityText: String
    @State private var selectedUnit: String
    @State private var customUnit: String
    @State private var note: String
    @State private var unitPriceText: String
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
        _unitPriceText = State(initialValue: entry?.unitPrice.map(String.init(describing:)) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Material") {
                    if entry == nil, !products.isEmpty {
                        Menu("Copy from product catalog", systemImage: "shippingbox.fill") {
                            ForEach(products) { product in
                                Button(productSelectionTitle(for: product)) {
                                    apply(product)
                                }
                            }
                        }
                    }
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

                    TextField("Unit price, excluding VAT", text: $unitPriceText)
                        .keyboardType(.decimalPad)
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
                    unitPriceText = entry.unitPrice.map {
                        EntryFormatting.formatDecimal($0, locale: locale)
                    } ?? ""
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
        let trimmedPrice = unitPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let unitPrice = trimmedPrice.isEmpty ? nil : EntryFormatting.parseDecimal(trimmedPrice, locale: locale)

        showNameError = trimmedName.isEmpty
        showQuantityError = quantity == nil || quantity.map { $0 <= 0 } == true
        showUnitError = resolvedUnit.isEmpty
        guard !trimmedName.isEmpty,
              let quantity,
              quantity > 0,
              !resolvedUnit.isEmpty,
              trimmedPrice.isEmpty || unitPrice.map({ $0 >= 0 }) == true else {
            if !trimmedPrice.isEmpty, unitPrice == nil || unitPrice.map({ $0 < 0 }) == true {
                errorMessage = String(localized: "Enter a valid unit price using the local decimal separator.")
            }
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
        savedEntry.unitPrice = unitPrice
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

    private func apply(_ product: ProductCatalogItem) {
        name = product.name
        let isPreset = MaterialUnit.allCases.contains { $0.rawValue == product.unit }
        selectedUnit = isPreset ? product.unit : "custom"
        customUnit = isPreset ? "" : product.unit
        unitPriceText = EntryFormatting.formatDecimal(product.unitPrice, locale: locale)
    }

    private func productSelectionTitle(for product: ProductCatalogItem) -> String {
        let number = product.itemNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return number.isEmpty ? product.name : "\(number) – \(product.name)"
    }
}
