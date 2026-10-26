import SwiftData
import SwiftUI

enum SalesDocumentWorkflow {
    case orderConfirmation
    case invoice
}

struct SalesDocumentsView: View {
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

    private var invoices: [InvoiceRecord] {
        allInvoices.filter { $0.jobID == job.id }
    }

    var body: some View {
        Form {
            if workflow == .orderConfirmation {
                Section("Order confirmation") {
                    Button("Create order confirmation", systemImage: "doc.text", action: createOrderConfirmation)
                    Text("The order confirmation is generated from the job's current priced labor, materials, and driving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Invoice") {
                    if let invoice = invoices.first {
                        Button("Open invoice copy", systemImage: "doc.on.doc") {
                            open(invoice, isCopy: true)
                        }
                        Text("Invoice \(invoice.invoiceNumber) is approved and locked. New invoice numbers cannot be created for this job.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if job.hasInvoiceDraft {
                        Button("Edit invoice basis", systemImage: "pencil") {
                            isEditingInvoiceBasis = true
                        }
                        DatePicker("Due date", selection: $dueDate, in: Date.now..., displayedComponents: .date)
                        Button("Save draft", systemImage: "square.and.arrow.down", action: saveDraft)
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
        .navigationTitle(workflow == .orderConfirmation ? "Order confirmation" : "Invoice")
        .confirmationDialog("Approve and issue invoice?", isPresented: $showsInvoiceConfirmation, titleVisibility: .visible) {
            Button("Approve and issue", action: issueInvoice)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The invoice receives a permanent number and a locked copy of customer, company, lines, and prices.")
        }
        .confirmationDialog("Delete invoice draft?", isPresented: $showsDeleteDraftConfirmation, titleVisibility: .visible) {
            Button("Delete draft", role: .destructive, action: deleteDraft)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only the draft is deleted. The job and its entries are kept.")
        }
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
        .task(id: job.id) {
            dueDate = job.invoiceDraftDueDate
                ?? Calendar.current.date(byAdding: .day, value: 14, to: .now)
                ?? .now
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func createOrderConfirmation() {
        guard let company = profiles.first else {
            errorMessage = String(localized: "Complete the company profile in Settings first.")
            return
        }
        do {
            let snapshot = try SalesDocumentService.snapshot(job: job, company: company)
            let url = try SalesDocumentPDFService().generate(snapshot: snapshot, kind: .orderConfirmation, locale: locale)
            preview = SalesDocumentPreview(url: url, title: "Order confirmation")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func issueInvoice() {
        guard let company = profiles.first else {
            errorMessage = String(localized: "Complete the company profile in Settings first.")
            return
        }
        do {
            let invoice = try SalesDocumentService.issueInvoice(
                job: job, company: company, dueDate: dueDate, in: modelContext
            )
            open(invoice, isCopy: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createDraft() {
        job.hasInvoiceDraft = true
        job.invoiceDraftDueDate = dueDate
        saveDraftChanges()
    }

    private func saveDraft() {
        job.invoiceDraftDueDate = dueDate
        job.updatedAt = .now
        saveDraftChanges()
    }

    private func deleteDraft() {
        job.hasInvoiceDraft = false
        saveDraftChanges()
    }

    private func saveDraftChanges() {
        do {
            try modelContext.save()
        } catch {
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
