import SwiftData
import SwiftUI

struct JobFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \Customer.name) private var customers: [Customer]
    @Query private var profiles: [CompanyProfile]
    let job: JobRecord?

    @State private var title: String
    @State private var selectedCustomerID: UUID?
    @State private var workAddress: String
    @State private var details: String
    @State private var plannedDate: Date
    @State private var status: JobStatus
    @State private var estimatedHoursText: String
    @State private var hourlyRateText: String
    @State private var drivingKilometersText: String
    @State private var drivingRateText: String
    @State private var appliesVAT: Bool
    @State private var vatRateText: String
    @State private var isAddingCustomer = false
    @State private var showTitleError = false
    @State private var showCustomerError = false
    @State private var errorMessage: String?
    @State private var didApplyCompanyRates = false

    init(job: JobRecord? = nil) {
        self.job = job
        _title = State(initialValue: job?.title ?? "")
        _selectedCustomerID = State(initialValue: job?.customer.id)
        _workAddress = State(initialValue: job?.workAddress ?? "")
        _details = State(initialValue: job?.details ?? "")
        _plannedDate = State(initialValue: job?.plannedDate ?? .now)
        _status = State(initialValue: job?.status ?? .planned)
        _estimatedHoursText = State(initialValue: job?.estimatedHours.map(String.init(describing:)) ?? "")
        _hourlyRateText = State(initialValue: job?.hourlyRate.map(String.init(describing:)) ?? "")
        _drivingKilometersText = State(initialValue: job?.drivingKilometers.map(String.init(describing:)) ?? "")
        _drivingRateText = State(initialValue: job?.drivingRatePerKilometer.map(String.init(describing:)) ?? "")
        _appliesVAT = State(initialValue: job?.vatRatePercent != nil)
        _vatRateText = State(initialValue: job?.vatRatePercent.map(String.init(describing:)) ?? "25")
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

                JobPriceEstimateSection(
                    estimatedHoursText: $estimatedHoursText,
                    hourlyRateText: $hourlyRateText,
                    drivingKilometersText: $drivingKilometersText,
                    drivingRateText: $drivingRateText,
                    appliesVAT: $appliesVAT,
                    vatRateText: $vatRateText
                )
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
            .task(id: profiles.first?.id) {
                applyInitialPriceFields()
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

        let estimatedHours = optionalDecimal(estimatedHoursText)
        let hourlyRate = optionalDecimal(hourlyRateText)
        let drivingKilometers = optionalDecimal(drivingKilometersText)
        let drivingRate = optionalDecimal(drivingRateText)
        let vatRate = appliesVAT ? optionalDecimal(vatRateText) : nil
        let enteredValues = [estimatedHoursText, hourlyRateText, drivingKilometersText, drivingRateText]
        guard zip(enteredValues, [estimatedHours, hourlyRate, drivingKilometers, drivingRate])
            .allSatisfy({ $0.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.1 != nil }),
              !appliesVAT || vatRate != nil else {
            errorMessage = String(localized: "Enter positive price values using the local decimal separator.")
            return
        }

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
            savedJob.estimatedHours = estimatedHours
            savedJob.hourlyRate = hourlyRate
            savedJob.drivingKilometers = drivingKilometers
            savedJob.drivingRatePerKilometer = drivingRate
            savedJob.vatRatePercent = vatRate
            savedJob.updatedAt = .now
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The job could not be saved. \(error.localizedDescription)")
        }
    }

    private func optionalDecimal(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let value = EntryFormatting.parseDecimal(trimmed, locale: locale),
              value >= 0 else { return nil }
        return value
    }

    private func applyInitialPriceFields() {
        guard !didApplyCompanyRates else { return }
        if let job {
            estimatedHoursText = job.estimatedHours.map { EntryFormatting.formatDecimal($0, locale: locale) } ?? ""
            hourlyRateText = job.hourlyRate.map { EntryFormatting.formatDecimal($0, locale: locale) } ?? ""
            drivingKilometersText = job.drivingKilometers.map { EntryFormatting.formatDecimal($0, locale: locale) } ?? ""
            drivingRateText = job.drivingRatePerKilometer.map { EntryFormatting.formatDecimal($0, locale: locale) } ?? ""
            vatRateText = job.vatRatePercent.map { EntryFormatting.formatDecimal($0, locale: locale) } ?? "25"
            didApplyCompanyRates = true
        } else if let profile = profiles.first {
            hourlyRateText = profile.defaultHourlyRate.map {
                EntryFormatting.formatDecimal($0, locale: locale)
            } ?? ""
            drivingRateText = profile.defaultDrivingRatePerKilometer.map {
                EntryFormatting.formatDecimal($0, locale: locale)
            } ?? ""
            appliesVAT = profile.isVATRegistered
            didApplyCompanyRates = true
        }
    }
}

private struct JobPriceEstimateSection: View {
    @Binding var estimatedHoursText: String
    @Binding var hourlyRateText: String
    @Binding var drivingKilometersText: String
    @Binding var drivingRateText: String
    @Binding var appliesVAT: Bool
    @Binding var vatRateText: String

    var body: some View {
        Section {
            TextField("Estimated hours", text: $estimatedHoursText)
                .keyboardType(.decimalPad)
            TextField("Hourly rate, excluding VAT", text: $hourlyRateText)
                .keyboardType(.decimalPad)
            TextField("Driving distance in km", text: $drivingKilometersText)
                .keyboardType(.decimalPad)
            TextField("Price per km, excluding VAT", text: $drivingRateText)
                .keyboardType(.decimalPad)
            Toggle("Add VAT", isOn: $appliesVAT)
            if appliesVAT {
                TextField("VAT rate in percent", text: $vatRateText)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Price estimate")
        } footer: {
            Text("Company rates are filled in automatically for new jobs and can be overridden here. Material prices are entered on each material line.")
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
