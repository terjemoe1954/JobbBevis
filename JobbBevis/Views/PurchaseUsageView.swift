import SwiftData
import SwiftUI

struct PurchaseUsageView: View {
    @Environment(\.canEditJob) private var canEditJob
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let item: PurchaseItem
    private let expectedUsed: Decimal
    private let expectedUpdatedAt: Date
    @State private var quantityText = ""
    @State private var operationID = UUID()
    @State private var saving = false
    @State private var errorMessage: String?

    init(item: PurchaseItem) {
        self.item = item
        expectedUsed = item.usedQuantity
        expectedUpdatedAt = item.updatedAt
    }

    private var quantity: Decimal? { EntryFormatting.parseDecimal(quantityText, locale: locale) }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.displayName) {
                    LabeledContent("Planned quantity", value: EntryFormatting.formatDecimal(item.quantity, locale: locale))
                    LabeledContent("Already registered", value: EntryFormatting.formatDecimal(item.usedQuantity, locale: locale))
                    LabeledContent("Remaining quantity", value: EntryFormatting.formatDecimal(item.remainingQuantity, locale: locale))
                    HStack {
                        Text("Unit")
                        Spacer()
                        if let unit = MaterialUnit(rawValue: item.unit) { Text(unit.title) } else { Text(item.unit) }
                    }
                }
                Section("Register used quantity") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Quantity used now").font(.headline)
                            if let unit = MaterialUnit(rawValue: item.unit) {
                                Text(unit.abbreviation).foregroundStyle(.secondary)
                            } else {
                                Text(item.unit).foregroundStyle(.secondary)
                            }
                        }
                        TextField("Used now", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(minHeight: 44)
                            .accessibilityLabel(Text("Quantity used now"))
                        Text("Enter only the quantity used this time.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let quantity, !quantity.isNaN, quantity > 0 {
                        LabeledContent("Usage amount excluding VAT", value: PriceEstimateCalculator.currency(quantity * item.unitPrice, locale: locale))
                        if quantity > item.remainingQuantity {
                            Text("Usage exceeds the planned quantity.").foregroundStyle(.orange)
                        }
                    }
                    Text("Only the entered quantity is added to materials. Planned quantity and price remain unchanged.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !item.linkedMaterials.isEmpty {
                    Section("Registered usage") {
                        ForEach(item.linkedMaterials.sorted { $0.createdAt < $1.createdAt }) { material in
                            LabeledContent(material.displayName, value: EntryFormatting.formatDecimal(material.quantity, locale: locale))
                        }
                        Text("Edit or delete these registrations under Materials. The usage summary updates automatically.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .disabled(saving)
            .disabled(!canEditJob)
            .navigationTitle("Register used quantity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register usage", action: register)
                        .disabled(!canEditJob || saving || quantity.map { $0.isNaN || $0 <= 0 } != false)
                }
            }
            .onAppear {
                if quantityText.isEmpty, item.remainingQuantity > 0 {
                    quantityText = EntryFormatting.formatDecimal(item.remainingQuantity, locale: locale)
                }
            }
        }
    }

    private func register() {
        guard canEditJob else { return }
        guard !saving, let quantity else { return }
        saving = true
        defer { saving = false }
        do {
            try MaterialTransferService.registerUsage(
                for: item, quantity: quantity, operationID: operationID,
                expectedUsed: expectedUsed, expectedUpdatedAt: expectedUpdatedAt, in: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
