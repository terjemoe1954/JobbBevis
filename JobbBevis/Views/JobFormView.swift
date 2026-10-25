import SwiftData
import SwiftUI

struct JobFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.name) private var customers: [Customer]
    let job: JobRecord?

    @State private var title: String
    @State private var selectedCustomerID: UUID?
    @State private var workAddress: String
    @State private var details: String
    @State private var plannedDate: Date
    @State private var status: JobStatus
    @State private var isAddingCustomer = false
    @State private var showTitleError = false
    @State private var showCustomerError = false
    @State private var errorMessage: String?

    init(job: JobRecord? = nil) {
        self.job = job
        _title = State(initialValue: job?.title ?? "")
        _selectedCustomerID = State(initialValue: job?.customer.id)
        _workAddress = State(initialValue: job?.workAddress ?? "")
        _details = State(initialValue: job?.details ?? "")
        _plannedDate = State(initialValue: job?.plannedDate ?? .now)
        _status = State(initialValue: job?.status ?? .planned)
    }

    var body: some View {
        NavigationStack {
            Form {
                JobBasicsSection(
                    title: $title,
                    selectedCustomerID: $selectedCustomerID,
                    plannedDate: $plannedDate,
                    status: $status,
                    customers: customers,
                    showTitleError: showTitleError,
                    showCustomerError: showCustomerError,
                    addCustomer: { isAddingCustomer = true }
                )

                JobLocationSection(
                    workAddress: $workAddress,
                    customerAddress: selectedCustomer?.address ?? ""
                )

                Section("Description") {
                    TextField("Describe the work", text: $details, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .navigationTitle(job == nil ? "New job" : "Edit job")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .sheet(isPresented: $isAddingCustomer) {
                CustomerFormView { customer in
                    selectedCustomerID = customer.id
                }
            }
            .alert("Could not save changes", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var selectedCustomer: Customer? {
        customers.first { $0.id == selectedCustomerID }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        showTitleError = trimmedTitle.isEmpty
        showCustomerError = selectedCustomer == nil
        guard !trimmedTitle.isEmpty, let selectedCustomer else { return }

        do {
            let savedJob: JobRecord
            if let job {
                savedJob = job
            } else {
                savedJob = JobRecord(
                    jobNumber: try JobNumberService.nextNumber(in: modelContext),
                    title: trimmedTitle,
                    customer: selectedCustomer
                )
                modelContext.insert(savedJob)
            }

            savedJob.title = trimmedTitle
            savedJob.customer = selectedCustomer
            savedJob.workAddress = workAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            savedJob.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
            savedJob.plannedDate = plannedDate
            savedJob.status = status
            savedJob.updatedAt = .now
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The job could not be saved. \(error.localizedDescription)")
        }
    }
}

private struct JobBasicsSection: View {
    @Binding var title: String
    @Binding var selectedCustomerID: UUID?
    @Binding var plannedDate: Date
    @Binding var status: JobStatus
    let customers: [Customer]
    let showTitleError: Bool
    let showCustomerError: Bool
    let addCustomer: () -> Void

    var body: some View {
        Section("Job") {
            TextField("Title", text: $title)
            if showTitleError {
                Text("Enter a job title.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Picker("Customer", selection: $selectedCustomerID) {
                Text("Select customer").tag(nil as UUID?)
                ForEach(customers) { customer in
                    Text(customer.name).tag(customer.id as UUID?)
                }
            }
            if showCustomerError {
                Text("Select or create a customer.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button("New customer", systemImage: "person.badge.plus", action: addCustomer)

            DatePicker("Planned date", selection: $plannedDate, displayedComponents: .date)
            Picker("Status", selection: $status) {
                ForEach(JobStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
        }
    }
}

private struct JobLocationSection: View {
    @Binding var workAddress: String
    let customerAddress: String

    var body: some View {
        Section("Work address") {
            TextField("Work address", text: $workAddress, axis: .vertical)
                .lineLimit(2...4)

            Button("Copy customer address", systemImage: "doc.on.doc") {
                workAddress = customerAddress
            }
            .disabled(customerAddress.isEmpty)
        }
    }
}
