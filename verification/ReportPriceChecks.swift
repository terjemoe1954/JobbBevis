import Foundation
import SwiftData
import UIKit
import PDFKit
@main struct ReportPriceChecks {
 @MainActor static func main() async throws {
  let customer = Customer(name: "Fiktiv rapportkunde",address: "Testveien 1")
  let job = JobRecord(jobNumber: "REPORT-CHECK",title: "Rapportkontroll",customer: customer,details: String(repeating: "Lang tekst for å kontrollere sideskift og lesbarhet. ",count: 130),estimatedHours: 80,hourlyRate: 800,vatRatePercent: 25)
  let company = CompanyProfile(name: "Fiktivt testfirma",organizationNumber: "974761076",address: "Testveien 2",isVATRegistered: true)
  job.workEntries = [WorkEntry(workDate: .now,details: "Utført arbeid",durationMinutes: 4800,job: job)]
  job.purchaseItems = [PurchaseItem(supplier: "Test",itemName: "Sparkel",quantity: 10,unit: "kg",unitPrice: 65,job: job)]
  job.materialEntries = [
   MaterialEntry(name: "Sparkel",quantity: 2,unit: "kg",job: job,unitPrice: 65,itemNumber: "OV-V06"),
   MaterialEntry(name: "Sparkel",quantity: 8,unit: "kg",job: job,unitPrice: 65,itemNumber: "OV-V06"),
   MaterialEntry(name: "Montasjeforbruk",quantity: 1,unit: "package",job: job,unitPrice: 1800,itemNumber: "OV-V08"),
   MaterialEntry(name: "Elektrikerarbeid",quantity: 8,unit: "h",job: job,unitPrice: 1100),
   MaterialEntry(name: "Uten pris",quantity: 1,unit: "pcs",job: job)]
  var paths:[String] = []
  defer { for path in paths { try? PhotoFileStore().remove(relativePath: path) } }
  for (index,size) in [CGSize(width: 360,height: 640),CGSize(width: 640,height: 360)].enumerated() {
   let renderer = UIGraphicsImageRenderer(size: size)
   let image = renderer.image { ctx in
    (index == 0 ? UIColor.systemBlue : UIColor.systemGreen).setFill();ctx.fill(CGRect(origin: .zero,size: size))
    ("Fiktivt bilde - kontroll" as NSString).draw(at: CGPoint(x: 25,y: 25),withAttributes: [.font:UIFont.systemFont(ofSize: 18),.foregroundColor:UIColor.white])
   }
   let path = try await PhotoFileStore().importImageData(image.jpegData(compressionQuality: 0.8)!,jobID: job.id)
   paths.append(path)
   job.photos.append(JobPhoto(relativePath: path,category: index == 0 ? .before : .after,caption: "Fiktivt øvelsesbilde",sortOrder: index,job: job))
  }
  let locale=Locale(identifier: "nb_NO")
  let folder=URL(fileURLWithPath: "/private/tmp/JobbBevis-report-verification",isDirectory: true)
  try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true)
  for (name,options) in [
   ("uten-priser",ReportOptions(showsPrices: false)),
   ("med-priser",ReportOptions(showsPrices: true)),
   ("linjepriser",ReportOptions(includesPriceEstimate: false,showsPrices: true))] {
   let url=try PDFReportService().generate(job: job,company: company,options: options,locale: locale)
   defer { try? FileManager.default.removeItem(at: url) }
   let document=PDFDocument(url: url)!;let text=document.string!
   assert(document.pageCount >= 3)
   assert(text.contains("OV-V06") && text.contains("OV-V08"))
   assert(text.contains("pakke") && !text.contains("pkg"))
   if name == "uten-priser" {
    assert(!text.contains("Enhetspris") && !text.contains("Linjesum") && !text.contains("64 000") && !text.contains("94 062"))
    assert(!text.contains("Registrert hittil") && !text.contains("Tilbudsgrunnlag"))
   } else {
    assert(text.contains("Enhetspris") && text.contains("Linjesum") && text.contains("Ingen pris registrert"))
    assert(text.contains("130,00") && text.contains("520,00"))
    if name == "med-priser" {
     assert(text.contains("Registrert hittil") && text.contains("Tilbudsgrunnlag"))
     assert(text.contains("94 062,50"))
    } else { assert(!text.contains("Registrert hittil")) }
   }
   let output=folder.appending(path: name+".pdf");try? FileManager.default.removeItem(at: output);try FileManager.default.copyItem(at: url,to: output)
   print("PASS "+name+": "+String(document.pageCount)+" pages")
  }
 }
}
