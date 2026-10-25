import SwiftData
import SwiftUI

struct CustomerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let customer: Customer?
    let onSave: ((Customer) -> Void)?

    @State private var name: String
    @State private var contactPerson: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var showNameError = false
    @State private var errorMessage: String?

    init(customer: Customer? = nil, onSave: ((Customer) -> Void)? = nil) {
        self.customer = customer
        self.onSave = onSave
        _name = State(initialValue: customer?.name ?? "")
        _contactPerson = State(initialValue: customer?.contactPerson ?? "")
        _phone = State(initialValue: customer?.phone ?? "")
        _email = State(initialValue: customer?.email ?? "")
        _address = State(initialValue: customer?.address ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Name", text: $name)
                    if showNameError {
                        Text("Enter a customer name.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
            .navigationTitle(customer == nil ? "New customer" : "Edit customer")
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        showNameError = trimmedName.isEmpty
        guard !trimmedName.isEmpty else { return }

        let savedCustomer: Customer
        if let customer {
            savedCustomer = customer
        } else {
            savedCustomer = Customer(name: trimmedName)
            modelContext.insert(savedCustomer)
        }

        savedCustomer.name = trimmedName
        savedCustomer.contactPerson = contactPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.updatedAt = .now

        do {
            try modelContext.save()
            onSave?(savedCustomer)
            dismiss()
        } catch {
            errorMessage = String(localized: "The customer could not be saved. \(error.localizedDescription)")
        }
    }
}
