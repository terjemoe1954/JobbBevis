import SwiftData
import SwiftUI

struct CustomersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.name) private var customers: [Customer]
    @State private var searchText = ""
    @State private var isAddingCustomer = false
    @State private var customerPendingDeletion: Customer?
    @State private var deletionMessage: LocalizedStringResource?
    @State private var errorMessage: String?

    private var filteredCustomers: [Customer] {
        guard !searchText.isEmpty else { return customers }
        return customers.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.contactPerson.localizedStandardContains(searchText)
                || ($0.customerNumber?.localizedStandardContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if customers.isEmpty {
                    CustomerEmptyState(addCustomer: { isAddingCustomer = true })
                } else if filteredCustomers.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredCustomers) { customer in
                        NavigationLink {
                            CustomerDetailView(customer: customer)
                        } label: {
                            CustomerRowView(
                                name: customer.name,
                                customerNumber: customer.customerNumber,
                                contactPerson: customer.contactPerson,
                                jobCount: customer.jobs.count
                            )
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                requestDeletion(customer)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Customers")
            .searchable(text: $searchText, prompt: "Search customers")
            .toolbar {
                Button("New customer", systemImage: "plus") {
                    isAddingCustomer = true
                }
            }
            .sheet(isPresented: $isAddingCustomer) {
                CustomerFormView()
            }
            .alert(
                deletionMessage ?? "Delete customer?",
                isPresented: deletionAlertBinding,
                presenting: customerPendingDeletion
            ) { customer in
                if customer.jobs.isEmpty {
                    Button("Delete", role: .destructive) {
                        delete(customer)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { customer in
                if customer.jobs.isEmpty {
                    Text("This cannot be undone.")
                } else {
                    Text("The customer cannot be deleted because it has associated jobs.")
                }
            }
            .alert("Could not delete customer", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { customerPendingDeletion != nil },
            set: {
                if !$0 {
                    customerPendingDeletion = nil
                    deletionMessage = nil
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func requestDeletion(_ customer: Customer) {
        customerPendingDeletion = customer
        deletionMessage = customer.jobs.isEmpty
            ? "Delete customer?"
            : "Customer cannot be deleted"
    }

    private func delete(_ customer: Customer) {
        modelContext.delete(customer)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The customer could not be deleted. \(error.localizedDescription)")
        }
    }
}

private struct CustomerEmptyState: View {
    let addCustomer: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No customers", systemImage: "person.2")
        } description: {
            Text("Add your first customer to create a job.")
        } actions: {
            Button("New customer", systemImage: "plus", action: addCustomer)
        }
    }
}

private struct CustomerRowView: View {
    let name: String
    let customerNumber: String?
    let contactPerson: String
    let jobCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            if let customerNumber, !customerNumber.isEmpty {
                Text("Customer no. \(customerNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !contactPerson.isEmpty {
                Text(contactPerson)
                    .foregroundStyle(.secondary)
            }
            Text("\(jobCount) jobs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
