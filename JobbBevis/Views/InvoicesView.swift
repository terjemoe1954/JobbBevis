import SwiftData
import SwiftUI

struct InvoicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \InvoiceRecord.issuedAt, order: .reverse) private var invoices: [InvoiceRecord]
    @Query(sort: \CreditNoteRecord.issuedAt, order: .reverse) private var creditNotes: [CreditNoteRecord]
    @Query(sort: \JobRecord.plannedDate, order: .reverse) private var jobs: [JobRecord]
    @State private var preview: InvoiceArchivePreview?
    @State private var errorMessage: String?
    @State private var invoiceToCredit: InvoiceRecord?

    var body: some View {
        NavigationStack {
            List {
                if !invoiceDrafts.isEmpty {
                    Section("Invoice drafts") {
                        ForEach(invoiceDrafts) { job in
                            NavigationLink {
                                SalesDocumentsView(job: job, workflow: .invoice)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(job.title)
                                        .font(.headline)
                                    Text(job.jobNumber)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !jobsWithoutInvoiceOrDraft.isEmpty {
                    Section("Create invoice draft") {
                        ForEach(jobsWithoutInvoiceOrDraft) { job in
                            NavigationLink {
                                SalesDocumentsView(job: job, workflow: .invoice)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(job.title)
                                        .font(.headline)
                                    Text(job.jobNumber)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if invoices.isEmpty && invoiceDrafts.isEmpty {
                    ContentUnavailableView {
                        Label("No invoices", systemImage: "doc.text")
                    } description: {
                        Text("Create an invoice draft from a job. Drafts can be edited and deleted before approval.")
                    }
                } else {
                    Section("Approved invoices") {
                        ForEach(invoices) { invoice in
                            HStack {
                                Button {
                                    openCopy(invoice)
                                } label: {
                                    InvoiceArchiveRow(
                                        number: invoice.invoiceNumber,
                                        jobNumber: invoice.jobNumber,
                                        issuedAt: invoice.issuedAt,
                                        total: invoice.snapshot?.total,
                                        locale: locale
                                    )
                                }
                                .buttonStyle(.plain)

                                if creditNote(for: invoice) == nil {
                                    Button("Create credit note", systemImage: "arrow.uturn.backward.circle") {
                                        invoiceToCredit = invoice
                                    }
                                    .labelStyle(.iconOnly)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .accessibilityLabel("Fully credited")
                                }
                            }
                        }
                    }
                }

                if !creditNotes.isEmpty {
                    Section("Credit notes") {
                        ForEach(creditNotes) { creditNote in
                            Button {
                                open(creditNote)
                            } label: {
                                InvoiceArchiveRow(
                                    number: creditNote.creditNoteNumber,
                                    jobNumber: creditNote.jobNumber,
                                    issuedAt: creditNote.issuedAt,
                                    total: creditNote.snapshot.map { -$0.total },
                                    locale: locale
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Invoices")
            .sheet(item: $preview) { preview in
                PDFPreviewView(pdfURL: preview.url, title: preview.title)
            }
            .confirmationDialog(
                "Create full credit note?",
                isPresented: creditNoteConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button("Create credit note", action: issueCreditNote)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The credit note reverses the entire invoice and receives its own permanent number.")
            }
            .alert("Could not open invoice", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var invoiceDrafts: [JobRecord] {
        let invoicedJobIDs = Set(invoices.map(\.jobID))
        return jobs.filter { $0.hasInvoiceDraft && !invoicedJobIDs.contains($0.id) }
    }

    private var jobsWithoutInvoiceOrDraft: [JobRecord] {
        let invoicedJobIDs = Set(invoices.map(\.jobID))
        return jobs.filter { !$0.hasInvoiceDraft && !invoicedJobIDs.contains($0.id) }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var creditNoteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { invoiceToCredit != nil },
            set: { if !$0 { invoiceToCredit = nil } }
        )
    }

    private func creditNote(for invoice: InvoiceRecord) -> CreditNoteRecord? {
        creditNotes.first { $0.originalInvoiceID == invoice.id }
    }

    private func openCopy(_ invoice: InvoiceRecord) {
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
                    isCopy: true
                ),
                locale: locale
            )
            preview = InvoiceArchivePreview(url: url, title: "Invoice copy")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func issueCreditNote() {
        guard let invoice = invoiceToCredit else { return }
        do {
            let creditNote = try SalesDocumentService.issueCreditNote(for: invoice, in: modelContext)
            invoiceToCredit = nil
            open(creditNote)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func open(_ creditNote: CreditNoteRecord) {
        guard let snapshot = creditNote.snapshot else {
            errorMessage = String(localized: "The stored credit note could not be read.")
            return
        }
        do {
            let url = try SalesDocumentPDFService().generate(
                snapshot: snapshot,
                kind: .creditNote(
                    number: creditNote.creditNoteNumber,
                    issuedAt: creditNote.issuedAt,
                    originalInvoiceNumber: creditNote.originalInvoiceNumber
                ),
                locale: locale
            )
            preview = InvoiceArchivePreview(url: url, title: "Credit note")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InvoiceArchiveRow: View {
    let number: String
    let jobNumber: String
    let issuedAt: Date
    let total: Decimal?
    let locale: Locale

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Invoice \(number)")
                    .font(.headline)
                Text("Job \(jobNumber)")
                    .foregroundStyle(.secondary)
                Text(issuedAt, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let total {
                Text(PriceEstimateCalculator.currency(total, locale: locale))
            }
        }
        .contentShape(Rectangle())
    }
}

private struct InvoiceArchivePreview: Identifiable {
    let id = UUID()
    let url: URL
    let title: LocalizedStringResource
}
