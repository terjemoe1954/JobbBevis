import SwiftData
import SwiftUI

struct PurchaseListView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord

    @State private var isAddingItem = false
    @State private var selectedItem: PurchaseItem?
    @State private var itemPendingDeletion: PurchaseItem?
    @State private var errorMessage: String?

    private var orderedItems: [PurchaseItem] {
        job.purchaseItems.sorted {
            let supplierOrder = $0.supplier.localizedStandardCompare($1.supplier)
            if supplierOrder == .orderedSame {
                return $0.itemName.localizedStandardCompare($1.itemName) == .orderedAscending
            }
            return supplierOrder == .orderedAscending
        }
    }

    private var total: Decimal {
        job.purchaseItems.reduce(0) { $0 + $1.lineTotal }
    }

    var body: some View {
        List {
            if orderedItems.isEmpty {
                ContentUnavailableView {
                    Label("No purchase items", systemImage: "cart")
                } description: {
                    Text("Add items you plan to buy for this job.")
                } actions: {
                    Button("Add purchase item", systemImage: "plus") {
                        isAddingItem = true
                    }
                }
            } else {
                Section {
                    ForEach(orderedItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            PurchaseItemRow(item: item, locale: locale)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                itemPendingDeletion = item
                            }
                        }
                    }
                } footer: {
                    Text("Purchase prices are internal costs and are not added to the customer price estimate.")
                }

                Section {
                    LabeledContent(
                        "Total purchases excluding VAT",
                        value: PriceEstimateCalculator.currency(total, locale: locale)
                    )
                    .font(.headline)
                }
            }
        }
        .navigationTitle("Purchase list")
        .toolbar {
            Button("Add purchase item", systemImage: "plus") {
                isAddingItem = true
            }
        }
        .sheet(isPresented: $isAddingItem) {
            PurchaseItemFormView(job: job)
        }
        .sheet(item: $selectedItem) { item in
            PurchaseItemFormView(job: job, item: item)
        }
        .confirmationDialog(
            "Delete purchase item?",
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deletePendingItem)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Could not delete purchase item", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { itemPendingDeletion != nil },
            set: { if !$0 { itemPendingDeletion = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func deletePendingItem() {
        guard let itemPendingDeletion else { return }
        modelContext.delete(itemPendingDeletion)
        job.updatedAt = .now
        do {
            try modelContext.save()
            self.itemPendingDeletion = nil
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The purchase item could not be deleted. Try again.")
        }
    }
}

private struct PurchaseItemRow: View {
    let item: PurchaseItem
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.itemName)
                    .font(.headline)
                Spacer()
                Text(PriceEstimateCalculator.currency(item.lineTotal, locale: locale))
                    .font(.headline)
            }
            Text(item.supplier)
                .font(.subheadline)
            HStack(spacing: 4) {
                Text(EntryFormatting.formatDecimal(item.quantity, locale: locale))
                if let unit = MaterialUnit(rawValue: item.unit) {
                    Text(unit.title)
                } else {
                    Text(item.unit)
                }
                Text("×")
                Text(PriceEstimateCalculator.currency(item.unitPrice, locale: locale))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.subheadline)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
    }
}
