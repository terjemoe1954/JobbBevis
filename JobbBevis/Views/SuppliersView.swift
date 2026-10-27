import SwiftData
import SwiftUI

struct SuppliersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Supplier.supplierNumber), SortDescriptor(\Supplier.name)])
    private var suppliers: [Supplier]
    @State private var supplierToEdit: Supplier?
    @State private var isAdding = false
    @State private var supplierToDelete: Supplier?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if suppliers.isEmpty {
                ContentUnavailableView {
                    Label("No suppliers", systemImage: "truck.box")
                } description: {
                    Text("Create suppliers and link products to them.")
                } actions: {
                    Button("New supplier", systemImage: "plus") { isAdding = true }
                }
            } else {
                List(suppliers) { supplier in
                    Button {
                        supplierToEdit = supplier
                    } label: {
                        SupplierRow(supplier: supplier)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            supplierToDelete = supplier
                        }
                    }
                }
            }
        }
        .navigationTitle("Suppliers")
        .toolbar {
            Button("New supplier", systemImage: "plus") { isAdding = true }
        }
        .sheet(isPresented: $isAdding) { SupplierFormView() }
        .sheet(item: $supplierToEdit) { SupplierFormView(supplier: $0) }
        .confirmationDialog("Delete supplier?", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteSupplier)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Products keep the supplier name, but the supplier link will be removed.")
        }
        .alert("Could not delete supplier", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { supplierToDelete != nil }, set: { if !$0 { supplierToDelete = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func deleteSupplier() {
        guard let supplierToDelete else { return }
        for product in supplierToDelete.products {
            product.supplier = supplierToDelete.name
            product.supplierRecord = nil
        }
        modelContext.delete(supplierToDelete)
        do {
            try modelContext.save()
            self.supplierToDelete = nil
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The supplier could not be deleted. Try again.")
        }
    }
}

private struct SupplierRow: View {
    let supplier: Supplier

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(supplier.name)
                .font(.headline)
            Text("Supplier no. \(supplier.supplierNumber)")
                .foregroundStyle(.secondary)
            Text("\(supplier.products.count) products")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct SupplierFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let supplier: Supplier?
    let onSave: ((Supplier) -> Void)?

    @State private var supplierNumber: String
    @State private var name: String
    @State private var contactPerson: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var errorMessage: String?

    init(supplier: Supplier? = nil, onSave: ((Supplier) -> Void)? = nil) {
        self.supplier = supplier
        self.onSave = onSave
        _supplierNumber = State(initialValue: supplier?.supplierNumber ?? "")
        _name = State(initialValue: supplier?.name ?? "")
        _contactPerson = State(initialValue: supplier?.contactPerson ?? "")
        _phone = State(initialValue: supplier?.phone ?? "")
        _email = State(initialValue: supplier?.email ?? "")
        _address = State(initialValue: supplier?.address ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Supplier") {
                    TextField("Supplier number", text: $supplierNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("Name", text: $name)
                    TextField("Contact person", text: $contactPerson)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(supplier == nil ? "New supplier" : "Edit supplier")
            .task {
                guard supplier == nil, supplierNumber.isEmpty else { return }
                supplierNumber = (try? BusinessNumberService.nextSupplierNumber(in: modelContext)) ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .alert("Could not save supplier", isPresented: errorBinding) {
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var resolvedNumber = supplierNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "Enter a supplier name.")
            return
        }
        do {
            if resolvedNumber.isEmpty {
                resolvedNumber = try BusinessNumberService.nextSupplierNumber(in: modelContext)
            }
            guard try BusinessNumberService.isSupplierNumberAvailable(
                resolvedNumber,
                excluding: supplier?.id,
                in: modelContext
            ) else {
                errorMessage = String(localized: "The supplier number is already in use.")
                return
            }
            let saved = supplier ?? Supplier(supplierNumber: resolvedNumber, name: trimmedName)
            if supplier == nil { modelContext.insert(saved) }
            saved.supplierNumber = resolvedNumber
            saved.name = trimmedName
            saved.contactPerson = contactPerson.trimmingCharacters(in: .whitespacesAndNewlines)
            saved.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            saved.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            saved.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
            saved.updatedAt = .now
            for product in saved.products { product.supplier = trimmedName }
            try modelContext.save()
            onSave?(saved)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The supplier could not be saved. Try again.")
        }
    }
}
