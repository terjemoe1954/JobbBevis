import Foundation
import SwiftData

@main struct MaterialTransferChecks {
 @MainActor static func main() throws {
  let container = try ModelContainer(for: JobRecord.self, Customer.self, MaterialEntry.self, PurchaseItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let customer = Customer(name: "Test")
  let job = JobRecord(jobNumber: "TEST", title: "Test", customer: customer)
  context.insert(customer); context.insert(job)
  let item = PurchaseItem(supplier: "Test", itemName: "Sparkel", quantity: 10, unit: "kg", unitPrice: 65, job: job)
  context.insert(item); job.purchaseItems.append(item); try context.save()
  func add(_ quantity: Decimal, id: UUID = UUID()) throws -> MaterialEntry {
   try MaterialTransferService.registerUsage(for: item, quantity: quantity, operationID: id, expectedUsed: item.usedQuantity, expectedUpdatedAt: item.updatedAt, in: context)
  }
  let id = UUID(); let first = try add(2, id: id)
  assert(item.usedQuantity == 2 && item.remainingQuantity == 8)
  _ = try add(2, id: id)
  assert(item.usedQuantity == 2 && job.materialEntries.count == 1)
  let oldDate = item.updatedAt
  let second = try add(8)
  assert(item.usedQuantity == 10 && item.remainingQuantity == 0 && item.isTransferredToMaterials)
  assert(item.quantity == 10 && item.lineTotal == 650)
  do {
   _ = try MaterialTransferService.registerUsage(for: item, quantity: 1, operationID: UUID(), expectedUsed: 2, expectedUpdatedAt: oldDate, in: context)
   fatalError("Stale submission accepted")
  } catch MaterialTransferService.TransferError.changed { }
  do { _ = try add(0); fatalError("Zero accepted") } catch MaterialTransferService.TransferError.invalidQuantity { }
  second.quantity = 6; try context.save()
  assert(item.usedQuantity == 8 && item.remainingQuantity == 2)
  try MaterialTransferService.link(first, to: nil); try context.save()
  assert(item.usedQuantity == 6)
  try MaterialTransferService.link(first, to: item); try context.save()
  assert(item.usedQuantity == 8)
  let extra = try add(3)
  assert(item.usedQuantity == 11 && item.remainingQuantity == 0 && item.quantity == 10)
  try MaterialTransferService.link(extra, to: nil)
  job.materialEntries.removeAll { $0.id == extra.id }; context.delete(extra); try context.save()
  assert(item.usedQuantity == 8)
  first.sourcePurchaseItemID = nil; item.transferredMaterialID = first.id; try context.save()
  assert(item.usedQuantity == 8)
  try MaterialTransferService.link(first, to: item); try context.save()
  assert(item.transferredMaterialID == nil && item.usedQuantity == 8)
  print("PASS: partial usage, retry, stale submission, validation, edits, link/unlink, overuse, deletion, legacy link; plan and price preserved")
 }
}
