import SwiftData
import SwiftUI

enum SalesDocumentWorkflow {
    case bid
    case orderConfirmation
    case invoice
}

struct SalesDocumentsView: View {
    @Environment(AccessStore.self) private var access
    @Query private var jobs: [JobRecord]
    @State private var showsPlus = false
    private var canEdit: Bool { access.policy.canEdit(job, in: jobs) }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query private var profiles: [CompanyProfile]
    @Query(sort: \InvoiceRecord.issuedAt, order: .reverse) private var allInvoices: [InvoiceRecord]
    let job: JobRecord
    let workflow: SalesDocumentWorkflow
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var showsInvoiceConfirmation = false
    @State private var preview: SalesDocumentPreview?
    @State private var errorMessage: String?
    @State private var isEditingInvoiceBasis = false
    @State private var showsDeleteDraftConfirmation = false
    @State private var draftSavedMessage: String?
    @State private var preparedBid: SalesDocumentSnapshot?
    @State private var confirmsAcceptedBid = false

    private var invoices: [InvoiceRecord] {
        allInvoices.filter { $0.jobID == job.id }
    }

    var body: some View {
        Form {
            if job.isExercise {
                Section("Exercise mode") { Text("EXERCISE - DO NOT PAY").foregroundStyle(.orange) }
            }
            if workflow == .bid {
                Section("Bid") {
                    Button("Create bid", systemImage: "doc.text", action: createBid)
                    if job.acceptedBidSnapshot != nil {
                        Button("Open accepted bid", systemImage: "doc.badge.clock", action: openAcceptedBid)
                        Text("The accepted copy is preserved. Current estimates and registered usage do not change it.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if preparedBid != nil {
                        Button("Record customer acceptance", systemImage: "checkmark.seal") { if canEdit { confirmsAcceptedBid = true } else { showsPlus = true } }
                        Text("Record acceptance only after the customer has accepted the bid you just previewed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Edit estimate", systemImage: "pencil") {
                        if canEdit { isEditingInvoiceBasis = true } else { showsPlus = true }
                    }
                    NavigationLink {
                        PurchaseListView(job: job).jobEditingAccess(for: job)
                    } label: {
                        Label("Edit purchase list", systemImage: "cart")
                    }
                    Text("The bid uses estimated hours and driving, plus priced items from the purchase list.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if workflow == .orderConfirmation {
                Section("Order confirmation") {
                    Button("Create order confirmation", systemImage: "doc.text", action: createOrderConfirmation)
                    Text("The order confirmation uses registered work, registered driving, and priced materials.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Invoice") {
                    if !access.hasPlus && invoices.isEmpty {
                        Text("Use the free job PDF as invoice basis in your own invoicing system. Creating invoices in JobbBevis requires Plus.")
                        if job.hasInvoiceDraft {
                            Button("Preview invoice draft", systemImage: "doc.text.magnifyingglass", action: previewDraft)
                            Text("Your saved draft is kept.")
                        }
                        Button("See Free and Plus") { showsPlus = true }
                    } else if let invoice = invoices.first {
                        Button("Open invoice copy", systemImage: "doc.on.doc") {
                            open(invoice, isCopy: true)
                        }
                        Text("Invoice \(invoice.invoiceNumber) is approved and locked. New invoice numbers cannot be created for this job.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if job.hasInvoiceDraft {
                        LabeledContent("Customer", value: job.customer.name)
                        LabeledContent("Job number", value: job.jobNumber)
                        LabeledContent("Invoice date", value: Date.now.formatted(.dateTime.day().month().year().locale(locale)))
                        LabeledContent("Total", value: PriceEstimateCalculator.currency(PriceEstimateCalculator.summary(for: job, basis: .registered, isVATRegistered: profiles.first?.isVATRegistered ?? false).total, locale: locale))
                        Text(job.isExercise ? LocalizedStringResource("Exercise invoice - separate TEST series") : LocalizedStringResource("Ordinary invoice - permanent invoice number"))
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(JobDateValidation.issues(for: job, dueDate: dueDate, checksDelivery: true)) {
                            Text($0.message).foregroundStyle(.orange)
                        }
                        Toggle("Combine matching linked material lines", isOn: invoiceGroupingBinding)
                        Text("Only usage linked to the same purchase item with identical item number, name, unit and price is combined. Original registrations are kept.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Edit invoice basis", systemImage: "pencil") {
                            if canEdit { isEditingInvoiceBasis = true } else { showsPlus = true }
                        }
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                        Button("Save draft", systemImage: "square.and.arrow.down", action: saveDraft)
                        if let draftSavedMessage {
                            Text(draftSavedMessage).font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("Preview invoice draft", systemImage: "doc.text.magnifyingglass", action: previewDraft)
                        Text("Check the customer, lines, prices, VAT and due date before approval. The preview has no invoice number and does not lock the job.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Approve and issue invoice", systemImage: "checkmark.seal") {
                            showsInvoiceConfirmation = true
                        }
                        Button("Delete draft", systemImage: "trash", role: .destructive) {
                            showsDeleteDraftConfirmation = true
                        }
                        Text("Approval assigns the next invoice number and locks a snapshot. The invoice cannot be edited or deleted in the app.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Create invoice draft", systemImage: "doc.badge.plus", action: createDraft)
                        Text("A draft has no invoice number and can be edited or deleted before approval.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !invoices.isEmpty {
                    Section("Issued invoices") {
                        ForEach(invoices) { invoice in
                            Button {
                                open(invoice, isCopy: true)
                            } label: {
                                InvoiceRow(invoice: invoice, locale: locale)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .environment(\.canEditJob, canEdit)
        .navigationTitle(navigationTitle)
        .confirmationDialog("Approve and issue invoice?", isPresented: $showsInvoiceConfirmation, titleVisibility: .visible) {
            Button("Approve and issue", action: issueInvoice)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(invoiceConfirmationMessage)
        }
        .confirmationDialog("Record accepted bid?", isPresented: $confirmsAcceptedBid, titleVisibility: .visible) {
            Button("Record acceptance", action: recordAcceptance)
            Button("Cancel", role: .cancel) { }
        } message: {
            if let preparedBid {
                Text("Customer: \(preparedBid.customerName). Total: \(PriceEstimateCalculator.currency(preparedBid.total, locale: locale)). This preserves the last previewed bid as a dated copy.")
            }
        }
        .confirmationDialog("Delete invoice draft?", isPresented: $showsDeleteDraftConfirmation, titleVisibility: .visible) {
            Button("Delete draft", role: .destructive, action: deleteDraft)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only the draft is deleted. The job and its entries are kept.")
        }
        .sheet(isPresented: $showsPlus) { PlusSheet() }
        .sheet(item: $preview) { preview in
            PDFPreviewView(pdfURL: preview.url, title: preview.title)
        }
        .sheet(isPresented: $isEditingInvoiceBasis) {
            JobFormView(job: job)
        }
        .alert("Could not create document", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: dueDate) { _, _ in draftSavedMessage = nil }
        .task(id: job.id) {
            dueDate = job.invoiceDraftDueDate
                ?? Calendar.current.date(byAdding: .day, value: 14, to: .now)
                ?? .now
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var navigationTitle: LocalizedStringResource {
        switch workflow {
        case .bid: "Bid"
        case .orderConfirmation: "Order confirmation"
        case .invoice: "Invoice"
        }
    }

    private func createBid() {
        guard let company = profiles.first else {
            errorMessage = String(localized: "Complete the company profile in Settings first.")
            return
        }
        do {
            let snapshot = try SalesDocumentService.snapshot(
                job: job,
                company: company,
                basis: .estimate,
                locale: locale
            )
            let url = try SalesDocumentPDFService().generate(snapshot: snapshot, kind: .bid, locale: locale)
            preparedBid = snapshot
            preview = SalesDocumentPreview(url: url, title: "Bid")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordAcceptance() {
        guard canEdit else { showsPlus = true; return }
        guard let preparedBid else { return }
        do {
            try SalesDocumentService.recordAcceptedBid(preparedBid, for: job, in: modelContext)
            self.preparedBid = nil
            openAcceptedBid()
        } catch { errorMessage = error.localizedDescription }
    }

    private func openAcceptedBid() {
        guard let snapshot = job.acceptedBidSnapshot, let acceptedAt = job.acceptedBidAt else { return }
        do {
            let url = try SalesDocumentPDFService().generate(snapshot: snapshot, kind: .acceptedBid(acceptedAt: acceptedAt), locale: locale)
            preview = SalesDocumentPreview(url: url, title: "Accepted bid")
        } catch { errorMessage = error.localizedDescription }
    }

    private func createOrderConfirmation() {
        guard let company = profiles.first else {
            errorMessage = String(localized: "Complete the company profile in Settings first.")
            return
        }
        do {
            let snapshot = try SalesDocumentService.snapshot(job: job, company: company, locale: locale)
            let url = try SalesDocumentPDFService().generate(snapshot: snapshot, kind: .orderConfirmation, locale: locale)
            preview = SalesDocumentPreview(url: url, title: "Order confirmation")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func previewDraft() {
        guard let company = profiles.first else {
            errorMessage = String(localized: "Complete the company profile in Settings first.")
            return
        }
        do {
            let snapshot = try SalesDocumentService.snapshot(job: job, company: company, locale: locale)
            let url = try SalesDocumentPDFService().generate(
                snapshot: snapshot, kind: .invoiceDraft(dueDate: dueDate), locale: locale
            )
            preview = SalesDocumentPreview(url: url, title: "Invoice draft")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var invoiceGroupingBinding: Binding<Bool> {
        Binding(get: { job.combinesInvoiceLines }, set: { value in
            guard access.hasPlus else { return }
            job.combinesInvoiceLines = value
            job.updatedAt = .now
            draftSavedMessage = nil
            do { try modelContext.save() }
            catch {
                modelContext.rollback()
                errorMessage = String(localized: "The invoice draft could not be saved. Try again.")
            }
        })
    }

    private var invoiceConfirmationMessage: String {
        let mode = job.isExercise
            ? String(localized: "The exercise invoice receives a TEST number and is marked DO NOT PAY. The ordinary invoice series is unchanged.")
            : String(localized: "The invoice receives a permanent number and a locked copy of customer, company, lines, and prices.")
        let identity = String(localized: "Customer: \(job.customer.name). Job: \(job.jobNumber).")
        let warnings = JobDateValidation.issues(for: job, dueDate: dueDate, checksDelivery: true).map { String(localized: $0.message) }
        return ([mode, identity] + warnings + [String(localized: "Confirm only after checking the dates and the draft.")]).joined(separator: "\n\n")
    }

    private func issueInvoice() {
        guard access.hasPlus else { showsPlus = true; return }
        guard let company = profiles.first else {
            errorMessage = String(localized: "Complete the company profile in Settings first.")
            return
        }
        do {
            let invoice = try SalesDocumentService.issueInvoice(
                job: job,
                company: company,
                dueDate: dueDate,
                datesAcknowledged: true,
                locale: locale,
                in: modelContext
            )
            open(invoice, isCopy: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createDraft() {
        guard access.hasPlus else { showsPlus = true; return }
        job.hasInvoiceDraft = true
        job.invoiceDraftDueDate = dueDate
        saveDraftChanges()
    }

    private func saveDraft() {
        guard access.hasPlus else { showsPlus = true; return }
        job.invoiceDraftDueDate = dueDate
        job.updatedAt = .now
        saveDraftChanges()
    }

    private func deleteDraft() {
        guard access.hasPlus else { showsPlus = true; return }
        job.hasInvoiceDraft = false
        saveDraftChanges()
    }

    private func saveDraftChanges() {
        do {
            try modelContext.save()
            draftSavedMessage = job.hasInvoiceDraft ? String(localized: "The invoice draft is saved.") : nil
        } catch {
            draftSavedMessage = nil
            modelContext.rollback()
            errorMessage = String(localized: "The invoice draft could not be saved. Try again.")
        }
    }

    private func open(_ invoice: InvoiceRecord, isCopy: Bool) {
        guard let snapshot = invoice.snapshot else {
            errorMessage = String(localized: "The stored invoice could not be read.")
            return
        }
        do {
            let url = try SalesDocumentPDFService().generate(
                snapshot: snapshot,
                kind: .invoice(
                    number: invoice.invoiceNumber,
                    issuedAt: invoice.issuedAt,
                    dueDate: invoice.dueDate,
                    isCopy: isCopy
                ),
                locale: locale
            )
            preview = SalesDocumentPreview(url: url, title: isCopy ? "Invoice copy" : "Invoice")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InvoiceRow: View {
    let invoice: InvoiceRecord
    let locale: Locale

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Invoice \(invoice.invoiceNumber)").font(.headline)
                Text(invoice.issuedAt, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let total = invoice.snapshot?.total {
                Text(PriceEstimateCalculator.currency(total, locale: locale))
            }
        }
        .contentShape(Rectangle())
    }
}

private struct SalesDocumentPreview: Identifiable {
    let id = UUID()
    let url: URL
    let title: LocalizedStringResource
}
