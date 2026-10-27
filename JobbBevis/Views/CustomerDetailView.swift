import SwiftUI

struct CustomerDetailView: View {
    let customer: Customer
    @State private var isEditing = false

    var body: some View {
        List {
            CustomerContactSection(
                customerNumber: customer.customerNumber,
                contactPerson: customer.contactPerson,
                phone: customer.phone,
                email: customer.email,
                address: customer.address
            )

            Section("Jobs") {
                if customer.jobs.isEmpty {
                    Text("This customer has no jobs.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customer.jobs) { job in
                        NavigationLink {
                            JobDetailView(job: job)
                        } label: {
                            JobRowView(job: job)
                        }
                    }
                }
            }
        }
        .navigationTitle(customer.name)
        .toolbar {
            Button("Edit", systemImage: "pencil") {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            CustomerFormView(customer: customer)
        }
    }
}

private struct CustomerContactSection: View {
    let customerNumber: String?
    let contactPerson: String
    let phone: String
    let email: String
    let address: String

    var body: some View {
        Section("Contact details") {
            if let customerNumber, !customerNumber.isEmpty {
                LabeledContent("Customer number", value: customerNumber)
            }
            if !contactPerson.isEmpty {
                LabeledContent("Contact person", value: contactPerson)
            }
            if !phone.isEmpty {
                LabeledContent("Phone", value: phone)
            }
            if !email.isEmpty {
                LabeledContent("Email", value: email)
            }
            if !address.isEmpty {
                LabeledContent("Address", value: address)
            }
            if contactPerson.isEmpty && phone.isEmpty && email.isEmpty && address.isEmpty {
                Text("No contact details have been added.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
