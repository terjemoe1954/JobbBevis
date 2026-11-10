import Foundation
import PDFKit
@main struct AccountingSelectionChecks {
 @MainActor static func main() throws {
  let formatter=ISO8601DateFormatter()
  func date(_ value:String)->Date { formatter.date(from:value)! }
  var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"Europe/Oslo")!
  let lines=[SalesDocumentLine(id:UUID(),description:"Arbeid, kjøkken",quantity:2,unit:"h",unitPrice:1000,vatRatePercent:25),SalesDocumentLine(id:UUID(),description:"Sparkel \"fin\"",quantity:2,unit:"kg",unitPrice:65,vatRatePercent:25)]
  func invoice(_ number:String,_ issued:String,_ lines:[SalesDocumentLine],exercise:Bool=false)->InvoiceRecord {
   let snapshot=SalesDocumentSnapshot(sellerName:"Fiktivt testfirma",sellerOrganizationNumber:"974761076",sellerAddress:"Testveien 1",sellerPhone:"",sellerEmail:"",sellerBankAccount:"",sellerIsVATRegistered:true,sellerIsRegisteredInBusinessRegister:false,customerName:"Fiktiv kunde",customerOrganizationNumber:"",customerAddress:"Testveien 2",jobNumber:"EXPORT-TEST",jobTitle:"Fiktiv eksport",deliveryDate:date(issued),deliveryAddress:"Testveien 2",lines:lines,exerciseMode:exercise ? true:nil)
   return InvoiceRecord(invoiceNumber:number,jobID:UUID(),jobNumber:"EXPORT-TEST",issuedAt:date(issued),dueDate:date(issued).addingTimeInterval(14*86400),snapshotData:try! JSONEncoder().encode(snapshot))
  }
  let before=invoice("2026-00001","2026-11-07T22:59:59Z",lines)
  let first=invoice("2026-00002","2026-11-07T23:00:00Z",lines)
  let last=invoice("2026-00003","2026-11-10T22:59:59Z",[SalesDocumentLine(id:UUID(),description:"Tjeneste",quantity:1,unit:"h",unitPrice:500,vatRatePercent:25)])
  let after=invoice("2026-00004","2026-11-10T23:00:00Z",lines)
  let test=invoice("TEST-2026-00001","2026-11-09T12:00:00Z",lines,exercise:true)
  let all=[before,first,last,after,test,first]
  let from=date("2026-11-08T12:00:00Z"),through=date("2026-11-10T01:00:00Z")
  let selected=AccountingExportSelection.invoices(all,from:from,through:through,calendar:calendar)
  assert(Set(selected.map(\.id))==[first.id,last.id])
  let summary=try AccountingExportSelection.summary(selected)
  assert(summary.invoices==2 && summary.lines==3 && summary.subtotal==2630 && summary.vat==Decimal(string:"657.50")! && summary.total==Decimal(string:"3287.50")!)
  let single=AccountingExportSelection.invoices(all,from:from,through:through,excluding:[first.id],calendar:calendar)
  assert(single.count==1 && single[0].id==last.id)
  assert(AccountingExportSelection.invoices(all,from:through,through:from,calendar:calendar).isEmpty)
  assert(AccountingExportSelection.invoices(all,excluding:Set(all.map(\.id))).isEmpty)
  assert(AccountingExportSelection.invoices(all).count==4)
  var oslo=Calendar(identifier:.gregorian);oslo.timeZone=TimeZone(identifier:"Europe/Oslo")!
  let springDay=date("2026-03-29T12:00:00Z")
  let dstA=invoice("DST-1","2026-03-28T23:00:00Z",lines)
  let dstB=invoice("DST-2","2026-03-29T21:59:59Z",lines)
  let dstC=invoice("DST-3","2026-03-29T22:00:00Z",lines)
  assert(AccountingExportSelection.invoices([dstA,dstB,dstC],from:springDay,through:springDay,calendar:oslo).count==2)
  let invalid=InvoiceRecord(invoiceNumber:"INVALID",jobID:UUID(),jobNumber:"ERROR",issuedAt:Date.now,dueDate:Date.now,snapshotData:Data("broken".utf8))
  do {_=try AccountingExportSelection.summary([first,invalid]);fatalError("Unreadable copy accepted")}catch AccountingCSVExportError.invalidInvoice {}
  do {_=try AccountingCSVExportService().exportData(invoices:[]);fatalError("Empty selection accepted")}catch AccountingCSVExportError.noInvoices {}
  let csv=try AccountingCSVExportService().exportData(invoices:selected)
  let pdf=try AccountingReportPDFService().exportData(invoices:selected,locale:Locale(identifier:"nb_NO"))
  let text=PDFDocument(data:pdf)!.string!
  assert(text.contains(first.invoiceNumber) && text.contains(last.invoiceNumber) && !text.contains(before.invoiceNumber) && !text.contains(after.invoiceNumber) && !text.contains("TEST-"))
  assert(text.contains("3 287,50"))
  let folder=URL(fileURLWithPath:"/private/tmp/JobbBevis-export-verification",isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  try csv.write(to:folder.appending(path:"selected-invoices.csv"));try pdf.write(to:folder.appending(path:"selected-invoices.pdf"))
  print("PASS: inclusive date boundaries, manual selection, invalid period, empty selection, duplicate protection, TEST exclusion, unreadable copy rejection, DST boundaries, summary reconciliation and matching CSV/PDF selection")
 }
}
