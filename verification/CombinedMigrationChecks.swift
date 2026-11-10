import Foundation
import SwiftData
@main struct CombinedMigrationChecks {
 @MainActor static func main() throws {
  let folder=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
  let original=try Data(contentsOf:folder.appending(path:"original-snapshot.bin"))
  let schema=Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let configuration=ModelConfiguration(schema:schema,url:folder.appending(path:"JobbBevis.store"))
  func upgrade() throws {
   let container=try ModelContainer(for:schema,configurations:configuration);let context=ModelContext(container)
   let jobs=try context.fetch(FetchDescriptor<JobRecord>());assert(jobs.count==1)
   let job=jobs[0];let invoice=try context.fetch(FetchDescriptor<InvoiceRecord>())[0];let metadata=try context.fetch(FetchDescriptor<AppMetadata>())[0]
   assert(job.jobNumber=="JB-LEGACY" && job.customer.name=="Legacy fixture customer")
   assert(!job.isExercise && !job.combinesInvoiceLines && job.acceptedBidSnapshotData==nil)
   assert(invoice.invoiceNumber=="2026-00017" && invoice.snapshotData==original && !invoice.isExercise)
   assert(metadata.nextInvoiceSequence==18 && metadata.nextCreditNoteSequence==9 && metadata.nextExerciseInvoiceSequence==nil)
   let material=job.materialEntries[0],purchase=job.purchaseItems[0]
   assert(material.quantity==2 && material.unitPrice==65 && material.itemNumber==nil && material.sourcePurchaseItemID==nil)
   assert(purchase.quantity==10 && purchase.itemNumber==nil && purchase.transferredMaterialID==material.id && purchase.usedQuantity==2)
   job.isExercise=true;job.combinesInvoiceLines=true;purchase.itemNumber="EXPLICIT-TEST";metadata.nextExerciseInvoiceSequence=4;try context.save()
  }
  try upgrade()
  let reopened=try ModelContainer(for:schema,configurations:configuration);let context=ModelContext(reopened)
  let job=try context.fetch(FetchDescriptor<JobRecord>())[0];let metadata=try context.fetch(FetchDescriptor<AppMetadata>())[0]
  assert(job.isExercise && job.combinesInvoiceLines && job.purchaseItems[0].itemNumber=="EXPLICIT-TEST")
  assert(metadata.nextInvoiceSequence==18 && metadata.nextExerciseInvoiceSequence==4)
  let invoice=try context.fetch(FetchDescriptor<InvoiceRecord>())[0]
  assert(invoice.snapshotData==original)
  print("PASS: original pre-change schema upgrades directly to all new fields; old links, quantities, customer, invoice bytes and ordinary counters preserved; explicit new fields persist after reopening")
 }
}
