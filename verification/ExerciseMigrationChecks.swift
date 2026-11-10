import Foundation
import SwiftData
@main struct ExerciseMigrationChecks {
 @MainActor static func main() throws {
  let schema=Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let config=ModelConfiguration(schema:schema,url:URL(fileURLWithPath:"/private/tmp/JobbBevis-exercise-migration.store"))
  let container=try ModelContainer(for:schema,configurations:config);let context=ModelContext(container)
  let jobs=try context.fetch(FetchDescriptor<JobRecord>());let metadata=try context.fetch(FetchDescriptor<AppMetadata>())[0]
  assert(jobs.count==1 && jobs[0].jobNumber=="MIGRATION-1" && !jobs[0].isExercise)
  assert(metadata.nextInvoiceSequence==23 && metadata.nextCreditNoteSequence==11)
  assert(metadata.nextExerciseInvoiceSequence==nil && metadata.nextExerciseCreditNoteSequence==nil)
  jobs[0].isExercise=true;metadata.nextExerciseInvoiceSequence=4;try context.save()
  let reopened=ModelContext(container)
  let reloaded=try reopened.fetch(FetchDescriptor<JobRecord>())[0]
  assert(reloaded.isExercise)
  print("PASS: migration preserves ordinary counters and job; exercise mode defaults off; new exercise state persists")
 }
}
