import SwiftData
import SwiftUI

struct CustomerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKey.validatesNorwegianNumbers) private var validatesNorwegianNumbers = true
    let customer: Customer?
    let onSave: ((Customer) -> Void)?

    @State private var name: String
    @State private var customerNumber: String
    @State private var contactPerson: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var organizationNumber: String
    @State private var showNameError = false
    @State private var showOrganizationNumberError = false
    @State private var errorMessage: String?

    init(customer: Customer? = nil, onSave: ((Customer) -> Void)? = nil) {
        self.customer = customer
        self.onSave = onSave
        _name = State(initialValue: customer?.name ?? "")
        _customerNumber = State(initialValue: customer?.customerNumber ?? "")
        _contactPerson = State(initialValue: customer?.contactPerson ?? "")
        _phone = State(initialValue: customer?.phone ?? "")
        _email = State(initialValue: customer?.email ?? "")
        _address = State(initialValue: customer?.address ?? "")
        _organizationNumber = State(initialValue: customer?.organizationNumber ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Customer number", text: $customerNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("Name", text: $name)
                    if showNameError {
                        Text("Enter a customer name.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    TextField("Contact person", text: $contactPerson)
                    TextField("Organization number", text: $organizationNumber)
                        .keyboardType(.numbersAndPunctuation)
                    if showOrganizationNumberError {
                        Text("Enter a valid Norwegian organization number with 9 digits, or leave the field empty.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
        let trimmedCustomerNumber = customerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrganizationNumber = organizationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let validOrganizationNumber: String? = if trimmedOrganizationNumber.isEmpty {
            nil
        } else if validatesNorwegianNumbers {
            NorwegianNumberValidator.organizationNumberDigits(from: trimmedOrganizationNumber)
        } else {
            trimmedOrganizationNumber
        }
        showNameError = trimmedName.isEmpty
        showOrganizationNumberError = !trimmedOrganizationNumber.isEmpty && validOrganizationNumber == nil
        guard !trimmedName.isEmpty, !showOrganizationNumberError else { return }

        do {
            let resolvedNumber = trimmedCustomerNumber.isEmpty
                ? try BusinessNumberService.nextCustomerNumber(in: modelContext)
                : trimmedCustomerNumber
            guard try BusinessNumberService.isCustomerNumberAvailable(
                resolvedNumber,
                excluding: customer?.id,
                in: modelContext
            ) else {
                errorMessage = String(localized: "The customer number is already in use.")
                return
            }
            customerNumber = resolvedNumber
        } catch {
            errorMessage = String(localized: "The next customer number could not be created.")
            return
        }

        let savedCustomer: Customer
        if let customer {
            savedCustomer = customer
        } else {
            savedCustomer = Customer(name: trimmedName)
            modelContext.insert(savedCustomer)
        }

        savedCustomer.name = trimmedName
        savedCustomer.customerNumber = customerNumber
        savedCustomer.contactPerson = contactPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        savedCustomer.organizationNumber = validOrganizationNumber
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
