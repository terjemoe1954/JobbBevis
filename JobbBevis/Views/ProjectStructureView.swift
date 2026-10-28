import SwiftData
import SwiftUI

struct ProjectStructureView: View {
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    @State private var isAddingTrade = false
    @State private var isAddingParty = false
    @State private var isAddingPackage = false
    @State private var editingTrade: ProjectTrade?
    @State private var editingParty: ProjectParty?
    @State private var editingPackage: WorkPackage?
    @State private var errorMessage: String?

    var body: some View {
        List {
            ProjectTradesSection(trades: orderedTrades, edit: { editingTrade = $0 }, delete: deleteTrade)
            ProjectPartiesSection(parties: orderedParties, edit: { editingParty = $0 }, delete: deleteParty)
            WorkPackagesSection(packages: orderedPackages, edit: { editingPackage = $0 }, delete: deletePackage)
        }
        .appListAppearance()
        .navigationTitle("Project structure")
        .toolbar {
            Menu("Add", systemImage: "plus") {
                Button("Trade", systemImage: "wrench.and.screwdriver") { isAddingTrade = true }
                Button("Project party", systemImage: "person.2.badge.gearshape") { isAddingParty = true }
                Button("Work package", systemImage: "shippingbox") { isAddingPackage = true }
            }
        }
        .sheet(isPresented: $isAddingTrade) { ProjectTradeFormView(job: job) }
        .sheet(isPresented: $isAddingParty) { ProjectPartyFormView(job: job) }
        .sheet(isPresented: $isAddingPackage) { WorkPackageFormView(job: job) }
        .sheet(item: $editingTrade) { ProjectTradeFormView(job: job, trade: $0) }
        .sheet(item: $editingParty) { ProjectPartyFormView(job: job, party: $0) }
        .sheet(item: $editingPackage) { WorkPackageFormView(job: job, package: $0) }
        .alert("Could not save changes", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var orderedTrades: [ProjectTrade] {
        job.projectTrades.sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    private var orderedParties: [ProjectParty] {
        job.projectParties.sorted {
            ($0.supplier?.name ?? "").localizedStandardCompare($1.supplier?.name ?? "") == .orderedAscending
        }
    }

    private var orderedPackages: [WorkPackage] {
        job.workPackages.sorted {
            $0.packageNumber.localizedStandardCompare($1.packageNumber) == .orderedAscending
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func deleteTrade(_ trade: ProjectTrade) {
        guard !job.workPackages.contains(where: { $0.trade?.id == trade.id }),
              !job.projectParties.contains(where: { $0.trade?.id == trade.id }) else {
            errorMessage = String(localized: "Remove the trade from project parties and work packages before deleting it.")
            return
        }
        modelContext.delete(trade)
        saveDeletion()
    }

    private func deleteParty(_ party: ProjectParty) {
        for package in job.workPackages where package.responsibleParty?.id == party.id {
            package.responsibleParty = nil
        }
        modelContext.delete(party)
        saveDeletion()
    }

    private func deletePackage(_ package: WorkPackage) {
        modelContext.delete(package)
        saveDeletion()
    }

    private func saveDeletion() {
        job.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The change could not be saved. Try again.")
        }
    }
}

private struct ProjectTradesSection: View {
    let trades: [ProjectTrade]
    let edit: (ProjectTrade) -> Void
    let delete: (ProjectTrade) -> Void

    var body: some View {
        Section("Trades") {
            if trades.isEmpty {
                Text("No trades registered")
                    .foregroundStyle(.secondary)
            }
            ForEach(trades) { trade in
                Button { edit(trade) } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(trade.name).font(.headline)
                            Text(trade.code).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let hours = trade.plannedHours {
                            Text("\(hours, format: .number) h")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: trade.isInternal ? "house.fill" : "person.2.fill")
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(trade) }
                }
            }
        }
    }
}

private struct ProjectPartiesSection: View {
    let parties: [ProjectParty]
    let edit: (ProjectParty) -> Void
    let delete: (ProjectParty) -> Void

    var body: some View {
        Section("Project parties") {
            if parties.isEmpty {
                Text("No project parties registered")
                    .foregroundStyle(.secondary)
            }
            ForEach(parties) { party in
                Button { edit(party) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(party.supplier?.name ?? String(localized: "Internal resource")).font(.headline)
                        HStack {
                            Text(party.role.title)
                            if let trade = party.trade { Text("· \(trade.name)") }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(party) }
                }
            }
        }
    }
}

private struct WorkPackagesSection: View {
    @Environment(\.locale) private var locale
    let packages: [WorkPackage]
    let edit: (WorkPackage) -> Void
    let delete: (WorkPackage) -> Void

    var body: some View {
        Section {
            if packages.isEmpty {
                Text("No work packages registered")
                    .foregroundStyle(.secondary)
            }
            ForEach(packages) { package in
                Button { edit(package) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(package.packageNumber) – \(package.title)").font(.headline)
                            Spacer()
                            Text("\(package.progressPercent)%")
                        }
                        HStack {
                            Text(package.status.title)
                            if let trade = package.trade { Text("· \(trade.name)") }
                            Spacer()
                            Text(PriceEstimateCalculator.currency(package.totalBudgetExcludingVAT, locale: locale))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(package) }
                }
            }
        } header: {
            Text("Work packages")
        } footer: {
            Text("Work package budgets are excluding VAT and are not included in price estimates or invoices.")
        }
    }
}

private struct ProjectTradeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    let trade: ProjectTrade?
    @State private var code: String
    @State private var name: String
    @State private var plannedHoursText: String
    @State private var isInternal: Bool
    @State private var errorMessage: String?

    init(job: JobRecord, trade: ProjectTrade? = nil) {
        self.job = job
        self.trade = trade
        _code = State(initialValue: trade?.code ?? "")
        _name = State(initialValue: trade?.name ?? "")
        _plannedHoursText = State(initialValue: trade?.plannedHours.map(String.init(describing:)) ?? "")
        _isInternal = State(initialValue: trade?.isInternal ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Code", text: $code).textInputAutocapitalization(.characters)
                TextField("Name", text: $name)
                TextField("Planned hours", text: $plannedHoursText).keyboardType(.decimalPad)
                Toggle("Internal trade", isOn: $isInternal)
            }
            .navigationTitle(trade == nil ? "New trade" : "Edit trade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .alert("Could not save changes", isPresented: errorBinding) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "") }
        }
    }

    private var errorBinding: Binding<Bool> { Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }) }

    private func save() {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hours = plannedHoursText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : EntryFormatting.parseDecimal(plannedHoursText, locale: locale)
        guard !code.isEmpty, !name.isEmpty, hours.map { $0 >= 0 } ?? true,
              !job.projectTrades.contains(where: { $0.id != trade?.id && $0.code.localizedCaseInsensitiveCompare(code) == .orderedSame }) else {
            errorMessage = String(localized: "Enter a unique code, a name, and valid planned hours.")
            return
        }
        let saved = trade ?? ProjectTrade(code: code, name: name, job: job)
        if trade == nil { modelContext.insert(saved); job.projectTrades.append(saved) }
        saved.code = code; saved.name = name; saved.plannedHours = hours; saved.isInternal = isInternal; saved.updatedAt = .now
        persist()
    }

    private func persist() {
        job.updatedAt = .now
        do { try modelContext.save(); dismiss() } catch { modelContext.rollback(); errorMessage = error.localizedDescription }
    }
}

private struct ProjectPartyFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Supplier.name) private var suppliers: [Supplier]
    let job: JobRecord
    let party: ProjectParty?
    @State private var role: ProjectPartyRole
    @State private var supplierID: UUID?
    @State private var tradeID: UUID?
    @State private var contactPerson: String
    @State private var note: String
    @State private var errorMessage: String?

    init(job: JobRecord, party: ProjectParty? = nil) {
        self.job = job; self.party = party
        _role = State(initialValue: party?.role ?? .subcontractor)
        _supplierID = State(initialValue: party?.supplier?.id)
        _tradeID = State(initialValue: party?.trade?.id)
        _contactPerson = State(initialValue: party?.contactPerson ?? "")
        _note = State(initialValue: party?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Role", selection: $role) { ForEach(ProjectPartyRole.allCases) { Text($0.title).tag($0) } }
                Picker("Supplier", selection: $supplierID) {
                    Text("Internal resource").tag(nil as UUID?)
                    ForEach(suppliers) { Text("\($0.supplierNumber) – \($0.name)").tag($0.id as UUID?) }
                }
                Picker("Trade", selection: $tradeID) {
                    Text("No trade").tag(nil as UUID?)
                    ForEach(job.projectTrades.sorted(by: { $0.name < $1.name })) { Text($0.name).tag($0.id as UUID?) }
                }
                TextField("Contact person", text: $contactPerson)
                TextField("Note", text: $note, axis: .vertical).lineLimit(2...5)
            }
            .navigationTitle(party == nil ? "New project party" : "Edit project party")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .alert("Could not save changes", isPresented: errorBinding) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "") }
        }
    }

    private var errorBinding: Binding<Bool> { Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }) }
    private func save() {
        let supplier = suppliers.first { $0.id == supplierID }
        guard supplier != nil || role == .internalResource else {
            errorMessage = String(localized: "Select a supplier, or choose Internal resource as the role.")
            return
        }
        let saved = party ?? ProjectParty(role: role, job: job)
        if party == nil { modelContext.insert(saved); job.projectParties.append(saved) }
        saved.role = role; saved.supplier = supplier; saved.trade = job.projectTrades.first { $0.id == tradeID }
        saved.contactPerson = contactPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.note = note.trimmingCharacters(in: .whitespacesAndNewlines); saved.updatedAt = .now; job.updatedAt = .now
        do { try modelContext.save(); dismiss() } catch { modelContext.rollback(); errorMessage = error.localizedDescription }
    }
}

private struct WorkPackageFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    let package: WorkPackage?
    @State private var number: String
    @State private var title: String
    @State private var details: String
    @State private var status: WorkPackageStatus
    @State private var tradeID: UUID?
    @State private var partyID: UUID?
    @State private var budgetExcludingVAT: String
    @State private var plannedHours: String
    @State private var progress: Int
    @State private var errorMessage: String?

    init(job: JobRecord, package: WorkPackage? = nil) {
        self.job = job; self.package = package
        _number = State(initialValue: package?.packageNumber ?? "")
        _title = State(initialValue: package?.title ?? "")
        _details = State(initialValue: package?.details ?? "")
        _status = State(initialValue: package?.status ?? .planned)
        _tradeID = State(initialValue: package?.trade?.id)
        _partyID = State(initialValue: package?.responsibleParty?.id)
        _budgetExcludingVAT = State(initialValue: package?.budgetExcludingVAT.map(String.init(describing:)) ?? "")
        _plannedHours = State(initialValue: package?.plannedHours.map(String.init(describing:)) ?? "")
        _progress = State(initialValue: package?.progressPercent ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Work package") {
                    TextField("Package number", text: $number).textInputAutocapitalization(.characters)
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical).lineLimit(3...7)
                    Picker("Status", selection: $status) { ForEach(WorkPackageStatus.allCases) { Text($0.title).tag($0) } }
                    Picker("Trade", selection: $tradeID) {
                        Text("No trade").tag(nil as UUID?)
                        ForEach(job.projectTrades.sorted(by: { $0.name < $1.name })) { Text($0.name).tag($0.id as UUID?) }
                    }
                    Picker("Responsible party", selection: $partyID) {
                        Text("No responsible party").tag(nil as UUID?)
                        ForEach(job.projectParties) { Text($0.supplier?.name ?? String(localized: "Internal resource")).tag($0.id as UUID?) }
                    }
                    Stepper("Progress: \(progress)%", value: $progress, in: 0...100, step: 5)
                }
                Section("Budget excluding VAT") {
                    TextField("Total excluding VAT", text: $budgetExcludingVAT).keyboardType(.decimalPad)
                    TextField("Planned hours", text: $plannedHours).keyboardType(.decimalPad)
                }
            }
            .navigationTitle(package == nil ? "New work package" : "Edit work package")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .alert("Could not save changes", isPresented: errorBinding) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "") }
        }
    }

    private var errorBinding: Binding<Bool> { Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }) }
    private func decimal(_ text: String) -> Decimal? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : EntryFormatting.parseDecimal(text, locale: locale)
    }
    private func save() {
        let number = number.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let budget = decimal(budgetExcludingVAT); let hours = decimal(plannedHours)
        guard !number.isEmpty, !title.isEmpty,
              budget.map { $0 >= 0 } ?? true, hours.map { $0 >= 0 } ?? true,
              !job.workPackages.contains(where: { $0.id != package?.id && $0.packageNumber.localizedCaseInsensitiveCompare(number) == .orderedSame }) else {
            errorMessage = String(localized: "Enter a unique package number, a title, and valid budget amounts.")
            return
        }
        let saved = package ?? WorkPackage(packageNumber: number, title: title, job: job)
        if package == nil { modelContext.insert(saved); job.workPackages.append(saved) }
        saved.packageNumber = number; saved.title = title; saved.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.status = status; saved.trade = job.projectTrades.first { $0.id == tradeID }
        saved.responsibleParty = job.projectParties.first { $0.id == partyID }; saved.progressPercent = progress
        saved.budgetExcludingVAT = budget; saved.plannedHours = hours; saved.updatedAt = .now; job.updatedAt = .now
        do { try modelContext.save(); dismiss() } catch { modelContext.rollback(); errorMessage = error.localizedDescription }
    }
}
