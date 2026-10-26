import SwiftData
import SwiftUI

struct ProductCatalogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: [SortDescriptor(\ProductCatalogItem.supplier), SortDescriptor(\ProductCatalogItem.name)])
    private var products: [ProductCatalogItem]
    @State private var productToEdit: ProductCatalogItem?
    @State private var isAdding = false
    @State private var productToDelete: ProductCatalogItem?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if products.isEmpty {
                ContentUnavailableView {
                    Label("No products", systemImage: "shippingbox")
                } description: {
                    Text("Add reusable products with supplier, unit, and price excluding VAT.")
                } actions: {
                    Button("Add product", systemImage: "plus") { isAdding = true }
                }
            } else {
                List(products) { product in
                    Button {
                        productToEdit = product
                    } label: {
                        ProductCatalogRow(product: product, locale: locale)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            productToDelete = product
                        }
                    }
                }
            }
        }
        .navigationTitle("Product catalog")
        .toolbar {
            Button("Add product", systemImage: "plus") { isAdding = true }
        }
        .sheet(isPresented: $isAdding) { ProductCatalogItemFormView() }
        .sheet(item: $productToEdit) { ProductCatalogItemFormView(product: $0) }
        .confirmationDialog("Delete product?", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteProduct)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Existing job lines keep their copied product information and price.")
        }
        .alert("Could not delete product", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { productToDelete != nil }, set: { if !$0 { productToDelete = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func deleteProduct() {
        guard let productToDelete else { return }
        modelContext.delete(productToDelete)
        do {
            try modelContext.save()
            self.productToDelete = nil
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The product could not be deleted. Try again.")
        }
    }
}

private struct ProductCatalogRow: View {
    let product: ProductCatalogItem
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name).font(.headline)
            Text(product.supplier).foregroundStyle(.secondary)
            Text("Unit price: \(PriceEstimateCalculator.currency(product.unitPrice, locale: locale)) / \(product.unit)")
                .font(.subheadline)
        }
        .contentShape(Rectangle())
    }
}

struct ProductCatalogItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let product: ProductCatalogItem?
    @State private var supplier: String
    @State private var name: String
    @State private var unit: String
    @State private var priceText: String
    @State private var errorMessage: String?

    init(product: ProductCatalogItem? = nil) {
        self.product = product
        _supplier = State(initialValue: product?.supplier ?? "")
        _name = State(initialValue: product?.name ?? "")
        _unit = State(initialValue: product?.unit ?? MaterialUnit.pieces.rawValue)
        _priceText = State(initialValue: product.map { String(describing: $0.unitPrice) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Supplier", text: $supplier)
                    TextField("Name", text: $name)
                    TextField("Unit", text: $unit)
                    TextField("Unit price, excluding VAT", text: $priceText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(product == nil ? "New product" : "Edit product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onAppear {
                if let product {
                    priceText = EntryFormatting.formatDecimal(product.unitPrice, locale: locale)
                }
            }
            .alert("Could not save product", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        let supplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !supplier.isEmpty, !name.isEmpty, !unit.isEmpty,
              let price = EntryFormatting.parseDecimal(priceText, locale: locale), price >= 0 else {
            errorMessage = String(localized: "Enter supplier, product, unit, and a valid non-negative price.")
            return
        }
        let saved = product ?? ProductCatalogItem(supplier: supplier, name: name, unit: unit, unitPrice: price)
        if product == nil { modelContext.insert(saved) }
        saved.supplier = supplier
        saved.name = name
        saved.unit = unit
        saved.unitPrice = price
        saved.updatedAt = .now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The product could not be saved. Try again.")
        }
    }
}
