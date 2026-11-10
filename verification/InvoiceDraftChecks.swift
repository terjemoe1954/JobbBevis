import Foundation
import SwiftData
import PDFKit

@main struct InvoiceDraftChecks {
 @MainActor static func main() throws {
  let container = try ModelContainer(for: JobRecord.self, Customer.self, CompanyProfile.self, AppMetadata.self, InvoiceRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let customer = Customer(name: "Fiktiv kunde", address: "Testveien 1")
  let company = CompanyProfile(name: "Testfirma", organizationNumber: "974761076", address: "Testveien 2", bankAccount: "1234.45.68454", isVATRegistered: true)
  let job = JobRecord(jobNumber: "JB-TEST", title: "Fiktiv kjøkkenjobb", customer: customer, estimatedHours: 80, hourlyRate: 800, vatRatePercent: 25, hasInvoiceDraft: true)
  context.insert(customer); context.insert(company); context.insert(job)
  let work = WorkEntry(workDate: .now, details: "Øving", durationMinutes: 4800, job: job)
  context.insert(work); job.workEntries.append(work)
  let material = MaterialEntry(name: "Varer og tjenester", quantity: 1, unit: "package", job: job, unitPrice: 155850)
  context.insert(material); job.materialEntries.append(material)
  let metadata = AppMetadata(nextInvoiceSequence: 7); context.insert(metadata); try context.save()
  let updatedAt = job.updatedAt
  let due = ISO8601DateFormatter().date(from: "2026-11-30T12:00:00Z")!
  let snapshot = try SalesDocumentService.snapshot(job: job, company: company, locale: Locale(identifier: "nb_NO"))
  assert(snapshot.subtotal == 219850 && snapshot.vat == Decimal(string: "54962.50")! && snapshot.total == Decimal(string: "274812.50")!)
  let url = try SalesDocumentPDFService().generate(snapshot: snapshot, kind: .invoiceDraft(dueDate: due), locale: Locale(identifier: "nb_NO"))
  let document = PDFDocument(url: url)!
  let text = document.string!
  assert(text.contains("DRAFT") || text.contains("UTKAST"))
  assert(text.contains("30") && text.contains("2026"))
  assert(!text.contains("2026-00007"))
  let invoices = try context.fetch(FetchDescriptor<InvoiceRecord>())
  assert(invoices.isEmpty)
  assert(metadata.nextInvoiceSequence == 7 && job.hasInvoiceDraft && job.updatedAt == updatedAt)
  material.unitPrice = 155900
  let changed = try SalesDocumentService.snapshot(job: job, company: company)
  assert(changed.total == snapshot.total + Decimal(string: "62.50")!)
  let output = URL(fileURLWithPath: "/private/tmp/JobbBevis-fakturautkast-test.pdf")
  try? FileManager.default.removeItem(at: output)
  try FileManager.default.copyItem(at: url, to: output)
  print("PASS: draft totals, PDF marking, due date, no invoice allocation or job mutation, fresh snapshot after edits")
  print(output.path)
 }
}
