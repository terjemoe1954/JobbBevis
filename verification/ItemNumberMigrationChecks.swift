import Foundation
import SwiftData
@main struct ItemNumberMigrationChecks {
 @MainActor static func main() throws {
  let schema = Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let config = ModelConfiguration(schema: schema,url: URL(fileURLWithPath: "/private/tmp/JobbBevis-item-number-migration.store"))
  let container = try ModelContainer(for: schema,configurations: config)
  let context = ModelContext(container)
  let jobs = try context.fetch(FetchDescriptor<JobRecord>())
  assert(jobs.count == 1)
  let job = jobs[0]
  assert(job.jobNumber == "MIGRATION-1" && job.customer.name == "Migration fixture")
  let item = job.purchaseItems[0]; let material = job.materialEntries[0]
  assert(item.itemNumber == nil && material.itemNumber == nil)
  assert(item.itemName == "Gammel vare" && item.quantity == 10 && item.unitPrice == 65)
  assert(material.name == "Gammelt forbruk" && material.quantity == 2 && material.sourcePurchaseItemID == item.id && item.usedQuantity == 2)
  item.itemNumber = "EXPLICIT-1"; try context.save()
  let reopened = ModelContext(container)
  let reloaded = try reopened.fetch(FetchDescriptor<PurchaseItem>())[0]
  assert(reloaded.itemNumber == "EXPLICIT-1")
  print("PASS: old store migration preserves names, quantities, prices and source link; new numbers start empty and persist after explicit edit")
 }
}
