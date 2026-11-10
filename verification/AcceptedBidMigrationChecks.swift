import Foundation
import SwiftData
@main struct AcceptedBidMigrationChecks {
 @MainActor static func main() throws {
  let schema = Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let config = ModelConfiguration(schema: schema,url: URL(fileURLWithPath: "/private/tmp/JobbBevis-price-migration.store"))
  let container = try ModelContainer(for: schema,configurations: config)
  let context = ModelContext(container)
  let jobs = try context.fetch(FetchDescriptor<JobRecord>())
  assert(jobs.count == 1)
  let job = jobs[0]
  assert(job.jobNumber == "MIGRATION-1" && job.estimatedHours == 80 && job.customer.name == "Migration fixture")
  assert(job.acceptedBidSnapshotData == nil && job.acceptedBidAt == nil)
  job.acceptedBidAt = .now
  try context.save()
  print("PASS: old store opens with new optional fields; existing job and customer preserved; new fields save")
 }
}
