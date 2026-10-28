import Foundation
import UIKit

struct DirectoryReportPDFService {
    func generate(title: String, headings: [String], rows: [[String]]) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = try outputURL(title: title)
        try renderer.writePDF(to: url) { context in
            var y: CGFloat = 42

            func beginPage() {
                context.beginPage()
                y = 42
                (title as NSString).draw(at: CGPoint(x: 42, y: y), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 24)
                ])
                y += 42
                let header = headings.joined(separator: "  ·  ")
                (header as NSString).draw(in: CGRect(x: 42, y: y, width: 511, height: 24), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: UIColor.darkGray
                ])
                y += 28
            }

            beginPage()
            for row in rows {
                let line = row.joined(separator: "  ·  ")
                let rect = CGRect(x: 42, y: y, width: 511, height: 44)
                let height = ceil((line as NSString).boundingRect(
                    with: rect.size,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: UIFont.systemFont(ofSize: 10)],
                    context: nil
                ).height) + 10
                if y + height > 800 { beginPage() }
                (line as NSString).draw(in: CGRect(x: 42, y: y, width: 511, height: height), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10)
                ])
                y += height
            }
        }
        return url
    }

    private func outputURL(title: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "JobbBevisReports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeTitle = title.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return directory.appending(path: "\(safeTitle)-\(UUID().uuidString.prefix(8)).pdf")
    }
}
