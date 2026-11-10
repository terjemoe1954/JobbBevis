import Foundation
import SwiftData
@main struct LegacyStoreFixture {
 @MainActor static func main() throws {
  let folder=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  let schema=Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let container=try ModelContainer(for:schema,configurations:ModelConfiguration(schema:schema,url:folder.appending(path:"JobbBevis.store")))
  let context=ModelContext(container)
  let customer=Customer(customerNumber:"C-00001",name:"Legacy fixture customer",address:"Testveien 1")
  let job=JobRecord(jobNumber:"JB-LEGACY",title:"Keep this historic job",customer:customer,estimatedHours:8,hourlyRate:800,vatRatePercent:25)
  context.insert(customer);context.insert(job)
  let material=MaterialEntry(name:"Sparkel",quantity:2,unit:"kg",job:job,unitPrice:65);context.insert(material);job.materialEntries.append(material)
  let purchase=PurchaseItem(supplier:"Fixture supplier",itemName:"Sparkel",quantity:10,unit:"kg",unitPrice:65,transferredMaterialID:material.id,transferredAt:.now,job:job);context.insert(purchase);job.purchaseItems.append(purchase)
  let snapshot=SalesDocumentSnapshot(sellerName:"Historic fixture seller",sellerOrganizationNumber:"974761076",sellerAddress:"Testveien 2",sellerPhone:"",sellerEmail:"",sellerBankAccount:"1234.45.68454",sellerIsVATRegistered:true,sellerIsRegisteredInBusinessRegister:false,customerName:customer.name,customerOrganizationNumber:"",customerAddress:customer.address,jobNumber:job.jobNumber,jobTitle:job.title,deliveryDate:job.plannedDate,deliveryAddress:customer.address,lines:[SalesDocumentLine(id:UUID(),description:"Historic line",quantity:2,unit:"kg",unitPrice:65,vatRatePercent:25)])
  let data=try JSONEncoder().encode(snapshot)
  context.insert(InvoiceRecord(invoiceNumber:"2026-00017",jobID:job.id,jobNumber:job.jobNumber,issuedAt:.now,dueDate:Date.now.addingTimeInterval(14*86400),snapshotData:data))
  context.insert(AppMetadata(nextJobSequence:2,nextInvoiceSequence:18,nextCreditNoteSequence:9));try context.save()
  try data.write(to:folder.appending(path:"original-snapshot.bin"))
  print("Created pre-change store fixture")
 }
}
