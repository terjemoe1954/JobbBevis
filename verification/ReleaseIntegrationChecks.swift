import Foundation
import SwiftData

struct ReleaseIntegrationChecks {
 @MainActor static func run() throws {
  let schema=Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  func makeContext() throws -> ModelContext {
   let container=try ModelContainer(for:schema,configurations:ModelConfiguration(isStoredInMemoryOnly:true))
   return ModelContext(container)
  }
  let context=try makeContext()
  let company=CompanyProfile(name:"Fiktivt firma",organizationNumber:"974761076",address:"Testveien 1",bankAccount:"1234.45.68454",isVATRegistered:true)
  let customer=Customer(name:"Fiktiv kunde",address:"Testveien 2")
  let job=JobRecord(jobNumber:"RELEASE-TEST",title:"Samlet kontroll",customer:customer,estimatedHours:8,hourlyRate:800,vatRatePercent:25)
  job.isExercise=true
  context.insert(company);context.insert(customer);context.insert(job)
  let metadata=AppMetadata(nextInvoiceSequence:17,nextCreditNoteSequence:9,nextExerciseInvoiceSequence:3,nextExerciseCreditNoteSequence:4);context.insert(metadata)
  let work=WorkEntry(workDate:.now,details:"Øving",durationMinutes:480,job:job);context.insert(work);job.workEntries.append(work)
  let source=PurchaseItem(supplier:"Test",itemName:"Sparkel",quantity:10,unit:"kg",unitPrice:65,job:job,itemNumber:"OV-V06")
  context.insert(source);job.purchaseItems.append(source);try context.save()
  let first=try MaterialTransferService.registerUsage(for:source,quantity:2,operationID:UUID(),expectedUsed:0,expectedUpdatedAt:source.updatedAt,in:context)
  let second=try MaterialTransferService.registerUsage(for:source,quantity:8,operationID:UUID(),expectedUsed:2,expectedUpdatedAt:source.updatedAt,in:context)
  let separate=try SalesDocumentService.snapshot(job:job,company:company)
  assert(separate.lines.count==3)
  job.combinesInvoiceLines=true
  let combined=try SalesDocumentService.snapshot(job:job,company:company)
  assert(combined.lines.count==2 && combined.total==separate.total)
  let material=combined.lines.first { $0.itemNumber=="OV-V06" }!
  assert(material.quantity==10 && material.unitPrice==65)
  assert(Set(material.sourceMaterialIDs ?? [])==[first.id,second.id])
  assert(job.materialEntries.count==2 && first.quantity==2 && second.quantity==8 && source.quantity==10)
  let accepted=try SalesDocumentService.snapshot(job:job,company:company,basis:.estimate)
  try SalesDocumentService.recordAcceptedBid(accepted,for:job,in:context)
  let invoice=try SalesDocumentService.issueInvoice(job:job,company:company,dueDate:Date.now.addingTimeInterval(14*86400),in:context)
  assert(invoice.snapshot?.lines.count==2 && invoice.snapshot?.exerciseMode==true)
  let frozen=invoice.snapshotData
  job.combinesInvoiceLines=false;try context.save()
  assert(invoice.snapshotData==frozen)
  job.combinesInvoiceLines=true
  let beforeBackup=try BackupService().exportData(from:context)
  let restoreRoot=FileManager.default.temporaryDirectory.appending(path:"JobbBevis-Isolated-Restore-\(UUID().uuidString)",directoryHint:.isDirectory)
  defer {try? FileManager.default.removeItem(at:restoreRoot)}
  let service=BackupService(applicationDirectoryOverride:restoreRoot)
  let prepared=try service.prepareImport(data:beforeBackup)
  let destination=try makeContext()
  destination.insert(AppMetadata(nextInvoiceSequence:100,nextCreditNoteSequence:40,nextExerciseInvoiceSequence:50,nextExerciseCreditNoteSequence:30))
  var ordinarySnapshot=combined;ordinarySnapshot.exerciseMode=nil
  let priorOrdinary=InvoiceRecord(invoiceNumber:"2026-00150",jobID:UUID(),jobNumber:"HISTORY",issuedAt:.now,dueDate:.now,snapshotData:try JSONEncoder().encode(ordinarySnapshot))
  let priorTest=InvoiceRecord(invoiceNumber:"TEST-2026-00900",jobID:UUID(),jobNumber:"HISTORY-TEST",issuedAt:.now,dueDate:.now,snapshotData:try JSONEncoder().encode(combined))
  destination.insert(priorOrdinary);destination.insert(priorTest)
  destination.insert(CreditNoteRecord(creditNoteNumber:"KN-2026-00005",originalInvoiceID:priorOrdinary.id,originalInvoiceNumber:priorOrdinary.invoiceNumber,jobNumber:priorOrdinary.jobNumber,issuedAt:.now,snapshotData:priorOrdinary.snapshotData))
  destination.insert(CreditNoteRecord(creditNoteNumber:"TEST-KN-2026-00400",originalInvoiceID:priorTest.id,originalInvoiceNumber:priorTest.invoiceNumber,jobNumber:priorTest.jobNumber,issuedAt:.now,snapshotData:priorTest.snapshotData))
  try destination.save()
  let preservedOrdinary=priorOrdinary.snapshotData
  try service.restore(prepared,into:destination)
  let restored=try destination.fetch(FetchDescriptor<JobRecord>())[0]
  assert(restored.isExercise && restored.combinesInvoiceLines && restored.acceptedBidSnapshot==accepted)
  assert(restored.materialEntries.count==2 && restored.purchaseItems.count==1)
  assert(restored.purchaseItems[0].usedQuantity==10 && restored.purchaseItems[0].itemNumber=="OV-V06")
  assert(restored.materialEntries.allSatisfy { $0.itemNumber=="OV-V06" && $0.sourcePurchaseItemID==source.id })
  let records=try destination.fetch(FetchDescriptor<InvoiceRecord>())
  assert(records.count==3 && records.first { $0.id==invoice.id }?.snapshotData==frozen)
  assert(records.first { $0.id==priorOrdinary.id }?.snapshotData==preservedOrdinary)
  let restoredMetadata=try destination.fetch(FetchDescriptor<AppMetadata>())[0]
  assert(restoredMetadata.nextInvoiceSequence==151 && restoredMetadata.nextCreditNoteSequence==40)
  assert(restoredMetadata.nextExerciseInvoiceSequence==901 && restoredMetadata.nextExerciseCreditNoteSequence==401)
  // Similar names alone must never merge distinct registrations.
  func add(_ name:String="Sparkel",_ unit:String="kg",_ price:Decimal=65,_ number:String?="OV-V06",_ sourceID:UUID?=nil) {
   let entry=MaterialEntry(name:name,quantity:1,unit:unit,job:job,unitPrice:price,sourcePurchaseItemID:sourceID,itemNumber:number)
   context.insert(entry);job.materialEntries.append(entry)
  }
  add("Sparkel","kg",70,"OV-V06",source.id)
  add("Sparkel","kg",65,"OTHER",source.id)
  add("Sparkel","l",65,"OV-V06",source.id)
  add("Different name","kg",65,"OV-V06",source.id)
  add("Sparkel","kg",65,"OV-V06",UUID())
  add();add();try context.save()
  let protected=try SalesDocumentService.snapshot(job:job,company:company)
  assert(protected.lines.count==9)
  assert(protected.lines.filter { ($0.sourceMaterialIDs?.count ?? 0)>1 }.count==1)
  print("PASS: optional grouping preserves quantities and trace IDs; different identity/price/unit/name and unlinked entries stay separate; full backup restore preserves new fields, immutable historical invoices and all four number counters")
 }
}
