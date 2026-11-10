import Foundation
import SwiftData
import PDFKit

@main struct PriceSeparationChecks {
 @MainActor static func main() throws {
  let schema = Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let customer = Customer(name: "Fiktiv kunde", address: "Testveien 1")
  let company = CompanyProfile(name: "Testfirma", organizationNumber: "974761076", address: "Testveien 2", bankAccount: "1234.45.68454", isVATRegistered: true)
  let job = JobRecord(jobNumber: "JB-TEST", title: "Fiktiv kjøkkenjobb", customer: customer, estimatedHours: 80, hourlyRate: 800, vatRatePercent: 25)
  context.insert(customer);context.insert(company);context.insert(job)
  let planned = PurchaseItem(supplier: "Test",itemName: "Varer og tjenester",quantity: 1,unit: "package",unitPrice: 155850,job: job)
  context.insert(planned);job.purchaseItems.append(planned)
  let work = WorkEntry(workDate: .now,details: "Øving",durationMinutes: 480,job: job)
  context.insert(work);job.workEntries.append(work)
  let material = MaterialEntry(name: "Sparkel",quantity: 2,unit: "kg",job: job,unitPrice: 65)
  context.insert(material);job.materialEntries.append(material);try context.save()
  let offer = PriceEstimateCalculator.summary(for: job,basis: .estimate,isVATRegistered: true)
  let actual = PriceEstimateCalculator.summary(for: job,basis: .registered,isVATRegistered: true)
  assert(offer.total == Decimal(string: "274812.50")! && actual.total == Decimal(string: "8162.50")!)
  let snapshot = try SalesDocumentService.snapshot(job: job,company: company,basis: .estimate)
  let actualSnapshot = try SalesDocumentService.snapshot(job: job,company: company)
  assert(snapshot.total == offer.total && actualSnapshot.total == actual.total)
  assert(PriceEstimateCalculator.summary(for: job,basis: .estimate,isVATRegistered: false).total == 219850)
  let date = Date(timeIntervalSince1970: 1794139200)
  try SalesDocumentService.recordAcceptedBid(snapshot,for: job,at: date,in: context)
  let frozen = job.acceptedBidSnapshotData!
  planned.unitPrice = 200000;job.estimatedHours = 100;material.quantity = 10;customer.name = "Endret kunde";try context.save()
  assert(job.acceptedBidSnapshotData == frozen && job.acceptedBidSnapshot?.total == offer.total && job.acceptedBidAt == date)
  assert(job.acceptedBidSnapshot?.customerName == "Fiktiv kunde")
  do {try SalesDocumentService.recordAcceptedBid(snapshot,for: job,in: context);fatalError("Accepted copy overwritten")} catch SalesDocumentError.acceptedBidAlreadyRecorded {}
  let backup = try BackupService().exportData(from: context)
  _ = try BackupService().prepareImport(data: backup)
  let json = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
  let jobs = json["jobs"] as! [[String: Any]]
  assert(jobs.first?["acceptedBidSnapshotData"] as? String == frozen.base64EncodedString())
  var legacy = json;legacy["jobs"] = jobs.map { record in var copy=record;copy.removeValue(forKey: "acceptedBidSnapshotData");copy.removeValue(forKey: "acceptedBidAt");return copy }
  _ = try BackupService().prepareImport(data: JSONSerialization.data(withJSONObject: legacy))
  let invoices = try context.fetch(FetchDescriptor<InvoiceRecord>());assert(invoices.isEmpty)
  let pdf = try SalesDocumentPDFService().generate(snapshot: job.acceptedBidSnapshot!,kind: .acceptedBid(acceptedAt: date),locale: Locale(identifier: "nb_NO"))
  assert(PDFDocument(url: pdf)!.string!.contains("Fiktiv kunde"))
  print("PASS: planned vs registered totals match document basis, VAT registration, immutable accepted copy, duplicate protection, backup export, old backup compatibility, no invoice allocation")
 }
}
