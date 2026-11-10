import Foundation
import SwiftData
import PDFKit
@main struct ExerciseDateChecks {
 @MainActor static func main() throws {
  let schema = Schema([CompanyProfile.self,Customer.self,JobRecord.self,JobPhoto.self,WorkEntry.self,MaterialEntry.self,PurchaseItem.self,ProjectTrade.self,ProjectParty.self,WorkPackage.self,Supplier.self,ProductCatalogItem.self,InvoiceRecord.self,CreditNoteRecord.self,AppMetadata.self])
  let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let customer = Customer(name: "Fiktiv øvelseskunde",address: "Testveien 1")
  let company = CompanyProfile(name: "Testfirma",organizationNumber: "974761076",address: "Testveien 2",bankAccount: "1234.45.68454",isVATRegistered: true)
  context.insert(customer);context.insert(company)
  let metadata=AppMetadata(nextInvoiceSequence: 17,nextCreditNoteSequence: 9,nextExerciseInvoiceSequence: 3,nextExerciseCreditNoteSequence: 4);context.insert(metadata)
  func makeJob(_ number:String,_ exercise:Bool)->JobRecord {
   let job=JobRecord(jobNumber: number,title: "Fiktiv jobb",customer: customer,hourlyRate: 800,vatRatePercent: 25);job.isExercise=exercise;context.insert(job)
   let work=WorkEntry(workDate: .now,details: "Øving",durationMinutes: 480,job: job);context.insert(work);job.workEntries.append(work)
   for n in 0..<45 {
    let material=MaterialEntry(name: "Fiktiv vare "+String(n),quantity: 1,unit: "pcs",job: job,unitPrice: 10);context.insert(material);job.materialEntries.append(material)
   }
   return job
  }
  let real=makeJob("ORDINARY",false);let practice=makeJob("EXERCISE",true);try context.save()
  let due=Date.now.addingTimeInterval(14*86400)
  let ordinary=try SalesDocumentService.issueInvoice(job: real,company: company,dueDate: due,in: context)
  assert(ordinary.invoiceNumber.hasSuffix("00017") && !ordinary.isExercise && metadata.nextExerciseInvoiceSequence==3)
  let test=try SalesDocumentService.issueInvoice(job: practice,company: company,dueDate: due,in: context)
  assert(test.invoiceNumber.hasPrefix("TEST-") && test.invoiceNumber.hasSuffix("00003") && test.isExercise)
  assert(metadata.nextInvoiceSequence==18 && metadata.nextExerciseInvoiceSequence==4)
  let credit=try SalesDocumentService.issueCreditNote(for: test,in: context)
  assert(credit.creditNoteNumber.hasPrefix("TEST-KN-") && credit.creditNoteNumber.hasSuffix("00004"))
  assert(metadata.nextCreditNoteSequence==9 && metadata.nextExerciseCreditNoteSequence==5)
  assert(credit.snapshot?.exerciseMode == true)
  practice.isExercise=false;try context.save();assert(test.isExercise && test.snapshot?.exerciseMode == true);practice.isExercise=true
  let csv=String(data: try AccountingCSVExportService().exportData(invoices:[ordinary,test]),encoding:.utf8)!
  assert(csv.contains(ordinary.invoiceNumber) && !csv.contains("TEST-"))
  do { _=try AccountingCSVExportService().exportData(invoices:[test]);fatalError("Exercise exported") } catch AccountingCSVExportError.noInvoices {}
  let accountingPDF=try AccountingReportPDFService().exportData(invoices:[ordinary,test],locale:Locale(identifier:"nb_NO"))
  assert(!PDFDocument(data:accountingPDF)!.string!.contains("TEST-"))
  assert(SalesDocumentService.nextSequence(after:["2026-00017","TEST-2026-00999"],exercise:false)==18)
  assert(SalesDocumentService.nextSequence(after:["2026-00017","TEST-2026-00999"],exercise:true)==1000)
  let future=makeJob("DATE-WARNING",true);future.plannedDate=Date.now.addingTimeInterval(8*86400);future.workEntries[0].workDate=Date.now.addingTimeInterval(8*86400);try context.save()
  do { _=try SalesDocumentService.issueInvoice(job: future,company: company,dueDate: due,in: context);fatalError("Date check bypassed") } catch SalesDocumentError.datesNeedReview {}
  assert(metadata.nextExerciseInvoiceSequence==4)
  let savedDate=future.plannedDate
  _=try SalesDocumentService.issueInvoice(job: future,company: company,dueDate: due,datesAcknowledged:true,in: context)
  assert(future.plannedDate==savedDate)
  var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
  let formatter=ISO8601DateFormatter();let now=formatter.date(from:"2026-11-08T12:00:00Z")!
  let issues=JobDateValidation.issues(plannedDate:now,completedAt:now.addingTimeInterval(86400),workDates:[now.addingTimeInterval(2*86400)],dueDate:now.addingTimeInterval(-86400),checksDelivery:true,now:now,calendar:calendar)
  assert(issues.contains(.completionInFuture) && issues.contains(.futureWork) && issues.contains(.workAfterCompletion) && issues.contains(.deliveryInFuture) && issues.contains(.dueBeforeIssue) && issues.contains(.dueBeforeDelivery))
  assert(JobDateValidation.issues(plannedDate:now,completedAt:now.addingTimeInterval(-86400),workDates:[],now:now,calendar:calendar).contains(.completionBeforePlanned))
  assert(JobDateValidation.issues(plannedDate:now,completedAt:now.addingTimeInterval(3600),workDates:[now],now:now,calendar:calendar).isEmpty)
  let backup=try BackupService().exportData(from:context);_=try BackupService().prepareImport(data:backup)
  let json=try JSONSerialization.jsonObject(with:backup) as! [String:Any]
  assert((json["jobs"] as! [[String:Any]]).contains { $0["isExercise"] as? Bool == true })
  assert((json["metadata"] as! [[String:Any]])[0]["nextExerciseInvoiceSequence"] as? Int == 5)
  var oldSnapshotJSON=try JSONSerialization.jsonObject(with:ordinary.snapshotData) as! [String:Any]
  oldSnapshotJSON.removeValue(forKey:"exerciseMode")
  let decodedOldSnapshot=try JSONDecoder().decode(SalesDocumentSnapshot.self,from:JSONSerialization.data(withJSONObject:oldSnapshotJSON))
  assert(decodedOldSnapshot.exerciseMode == nil && decodedOldSnapshot.total == ordinary.snapshot?.total)
  var legacy=json
  legacy["jobs"]=(json["jobs"] as! [[String:Any]]).map { row in var r=row;r.removeValue(forKey:"isExercise");return r }
  legacy["metadata"]=(json["metadata"] as! [[String:Any]]).map { row in var r=row;r.removeValue(forKey:"nextExerciseInvoiceSequence");r.removeValue(forKey:"nextExerciseCreditNoteSequence");return r }
  _=try BackupService().prepareImport(data:JSONSerialization.data(withJSONObject:legacy))
  let folder=URL(fileURLWithPath:"/private/tmp/JobbBevis-exercise-verification",isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  let locale=Locale(identifier:"nb_NO")
  let snapshot=test.snapshot!
  let documents:[(String,SalesDocumentPDFService.Kind)]=[("ovelsesfaktura",.invoice(number:test.invoiceNumber,issuedAt:test.issuedAt,dueDate:test.dueDate,isCopy:false)),("ovelseskreditnota",.creditNote(number:credit.creditNoteNumber,issuedAt:credit.issuedAt,originalInvoiceNumber:test.invoiceNumber)),("ovelsestilbud",.bid)]
  for (name,kind) in documents {
   let url=try SalesDocumentPDFService().generate(snapshot:snapshot,kind:kind,locale:locale)
   let document=PDFDocument(url:url)!
   for page in 0..<document.pageCount { assert(document.page(at:page)!.string!.contains("ØVELSE - SKAL IKKE BETALES")) }
   assert(!document.string!.contains("1234.45.68454"))
   let out=folder.appending(path:name+".pdf");try? FileManager.default.removeItem(at:out);try FileManager.default.moveItem(at:url,to:out)
  }
  practice.details=String(repeating:"Fiktiv tekst for kontroll av sideskift. ",count:160)
  let report=try PDFReportService().generate(job:practice,company:company,options:ReportOptions(showsPrices:true),locale:locale)
  let document=PDFDocument(url:report)!
  for page in 0..<document.pageCount { assert(document.page(at:page)!.string!.contains("ØVELSE - SKAL IKKE BETALES")) }
  let out=folder.appending(path:"ovelsesrapport.pdf");try? FileManager.default.removeItem(at:out);try FileManager.default.moveItem(at:report,to:out)
  print("PASS: independent invoice and credit series, frozen exercise mode, accounting exclusion, date warnings and explicit acknowledgement, unchanged dates, backup compatibility, exercise marking on every PDF page and no payment account")
 }
}
