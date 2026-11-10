import Foundation
import SwiftData
@main struct ItemNumberChecks {
 @MainActor static func main() throws {
  let schema = Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let customer = Customer(name: "Fiktiv kunde")
  let job = JobRecord(jobNumber: "NUMBER-TEST",title: "Varenummer",customer: customer)
  context.insert(customer);context.insert(job)
  let product = ProductCatalogItem(itemNumber: "OV-V06",supplier: "Test",name: "Sparkel",unit: "kg",unitPrice: 65)
  context.insert(product)
  let item = PurchaseItem(supplier: product.supplier,itemName: product.name,quantity: 10,unit: product.unit,unitPrice: product.unitPrice,job: job,itemNumber: product.itemNumber)
  context.insert(item);job.purchaseItems.append(item);try context.save()
  func use(_ quantity: Decimal) throws -> MaterialEntry {
   try MaterialTransferService.registerUsage(for: item,quantity: quantity,operationID: UUID(),expectedUsed: item.usedQuantity,expectedUpdatedAt: item.updatedAt,in: context)
  }
  let first = try use(2);let second = try use(8)
  assert(first.itemNumber == "OV-V06" && second.itemNumber == "OV-V06" && item.usedQuantity == 10)
  assert(first.displayName == "OV-V06 · Sparkel" && item.displayName == "OV-V06 · Sparkel")
  product.itemNumber = "NEW-99";product.name = "Nytt navn";try context.save()
  assert(item.itemNumber == "OV-V06" && first.itemNumber == "OV-V06" && item.itemName == "Sparkel")
  let manual = MaterialEntry(name: "Tjeneste",quantity: 1,unit: "h",job: job,unitPrice: 800)
  context.insert(manual);job.materialEntries.append(manual);try context.save()
  assert(manual.displayName == "Tjeneste" && manual.itemNumber == nil)
  let backup = try BackupService().exportData(from: context)
  _ = try BackupService().prepareImport(data: backup)
  let json = try JSONSerialization.jsonObject(with: backup) as! [String:Any]
  let purchases = json["purchaseItems"] as! [[String:Any]]
  let materials = json["materials"] as! [[String:Any]]
  assert(purchases.first?["itemNumber"] as? String == "OV-V06")
  assert(materials.filter { $0["itemNumber"] as? String == "OV-V06" }.count == 2)
  var legacy = json
  for key in ["purchaseItems","materials"] {
   legacy[key] = (json[key] as! [[String:Any]]).map { record in var copy=record;copy.removeValue(forKey: "itemNumber");return copy }
  }
  _ = try BackupService().prepareImport(data: JSONSerialization.data(withJSONObject: legacy))
  print("PASS: numbered partial transfers, stable historic numbers after catalog edits, optional manual numbers, backup preservation and old backup compatibility")
 }
}
