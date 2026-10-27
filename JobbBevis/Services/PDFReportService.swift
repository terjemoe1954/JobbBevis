import Foundation
import SwiftUI
import UIKit

struct ReportOptions {
    var includesPhotos = true
    var includesWorkLog = true
    var includesMaterials = true
    var includesPriceEstimate = true
}

@MainActor
struct PDFReportService {
    private let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let margin: CGFloat = 44
    private let footerHeight: CGFloat = 28

    func generate(
        job: JobRecord,
        company: CompanyProfile?,
        options: ReportOptions,
        locale: Locale
    ) throws -> URL {
        let outputURL = try makeOutputURL(jobNumber: job.jobNumber)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let logoData = ManagedFileStore().data(relativePath: company?.logoRelativePath)
        let photoData = options.includesPhotos
            ? job.photos.sorted { $0.sortOrder < $1.sortOrder }.map {
                ($0, PhotoFileStore().data(relativePath: $0.relativePath))
            }
            : []

        try renderer.writePDF(to: outputURL) { context in
            var pageNumber = 0
            var y = margin

            func localized(_ key: String) -> String {
                switch key {
                case "Planned": String(localized: LocalizedStringResource("Planned", locale: locale))
                case "In progress": String(localized: LocalizedStringResource("In progress", locale: locale))
                case "Completed": String(localized: LocalizedStringResource("Completed", locale: locale))
                case "Before": String(localized: LocalizedStringResource("Before", locale: locale))
                case "During": String(localized: LocalizedStringResource("During", locale: locale))
                case "After": String(localized: LocalizedStringResource("After", locale: locale))
                case "pcs": String(localized: LocalizedStringResource("pcs", locale: locale))
                case "m": String(localized: LocalizedStringResource("m", locale: locale))
                case "m²": String(localized: LocalizedStringResource("m²", locale: locale))
                case "m³": String(localized: LocalizedStringResource("m³", locale: locale))
                case "l": String(localized: LocalizedStringResource("l", locale: locale))
                case "kg": String(localized: LocalizedStringResource("kg", locale: locale))
                case "package": String(localized: LocalizedStringResource("package", locale: locale))
                case "Job report": String(localized: LocalizedStringResource("Job report", locale: locale))
                case "Report date": String(localized: LocalizedStringResource("Report date", locale: locale))
                case "Job number": String(localized: LocalizedStringResource("Job number", locale: locale))
                case "Status": String(localized: LocalizedStringResource("Status", locale: locale))
                case "Customer": String(localized: LocalizedStringResource("Customer", locale: locale))
                case "Work address": String(localized: LocalizedStringResource("Work address", locale: locale))
                case "Planned date": String(localized: LocalizedStringResource("Planned date", locale: locale))
                case "Completed date": String(localized: LocalizedStringResource("Completed date", locale: locale))
                case "Description": String(localized: LocalizedStringResource("Description", locale: locale))
                case "Work log": String(localized: LocalizedStringResource("Work log", locale: locale))
                case "Total time": String(localized: LocalizedStringResource("Total time", locale: locale))
                case "Materials": String(localized: LocalizedStringResource("Materials", locale: locale))
                case "Photos": String(localized: LocalizedStringResource("Photos", locale: locale))
                case "Image unavailable": String(localized: LocalizedStringResource("Image unavailable", locale: locale))
                case "Registered": String(localized: LocalizedStringResource("Registered", locale: locale))
                case "Sample data – not a real customer or job": String(localized: LocalizedStringResource("Sample data – not a real customer or job", locale: locale))
                case "Price estimate": String(localized: LocalizedStringResource("Price estimate", locale: locale))
                case "Labor": String(localized: LocalizedStringResource("Labor", locale: locale))
                case "Driving": String(localized: LocalizedStringResource("Driving", locale: locale))
                case "Subtotal excluding VAT": String(localized: LocalizedStringResource("Subtotal excluding VAT", locale: locale))
                case "VAT": String(localized: LocalizedStringResource("VAT", locale: locale))
                case "Suggested total price": String(localized: LocalizedStringResource("Suggested total price", locale: locale))
                case "This is a non-binding price estimate, not an invoice or payment request.": String(localized: LocalizedStringResource("This is a non-binding price estimate, not an invoice or payment request.", locale: locale))
                default: key
                }
            }

            func localizedStatus(_ status: JobStatus) -> String {
                switch status {
                case .planned: localized("Planned")
                case .inProgress: localized("In progress")
                case .completed: localized("Completed")
                }
            }

            func localizedCategory(_ category: PhotoCategory) -> String {
                switch category {
                case .before: localized("Before")
                case .during: localized("During")
                case .after: localized("After")
                }
            }

            func localizedUnit(_ unit: MaterialUnit) -> String {
                switch unit {
                case .pieces: localized("pcs")
                case .millimeter: localized("mm")
                case .centimeter: localized("cm")
                case .meter: localized("m")
                case .squareMeter: localized("m²")
                case .cubicMeter: localized("m³")
                case .liter: localized("l")
                case .kilogram: localized("kg")
                case .hour: localized("h")
                case .package: localized("pkg")
                }
            }

            func finishPage() {
                guard pageNumber > 0 else { return }
                let footer = String(localized: LocalizedStringResource("Page \(pageNumber)", locale: locale))
                draw(
                    footer,
                    in: CGRect(
                        x: margin,
                        y: pageRect.height - margin + 8,
                        width: pageRect.width - margin * 2,
                        height: footerHeight
                    ),
                    font: .systemFont(ofSize: 9),
                    color: .darkGray,
                    alignment: .center
                )
            }

            func beginPage() {
                finishPage()
                context.beginPage()
                pageNumber += 1
                y = margin
            }

            func ensureSpace(_ height: CGFloat) {
                let bottom = pageRect.height - margin - footerHeight
                if y + height > bottom {
                    beginPage()
                }
            }

            func addText(
                _ text: String,
                font: UIFont,
                color: UIColor = .black,
                spacingAfter: CGFloat = 8
            ) {
                guard !text.isEmpty else { return }
                let width = pageRect.width - margin * 2
                let fullHeight = textHeight(text, width: width, font: font)
                let usableHeight = pageRect.height - margin * 2 - footerHeight

                if fullHeight <= usableHeight {
                    ensureSpace(fullHeight + spacingAfter)
                    draw(text, in: CGRect(x: margin, y: y, width: width, height: fullHeight), font: font, color: color)
                    y += fullHeight + spacingAfter
                    return
                }

                var remaining = text
                while !remaining.isEmpty {
                    let available = pageRect.height - margin - footerHeight - y
                    if available < font.lineHeight * 2 {
                        beginPage()
                        continue
                    }
                    let split = fittingPrefixLength(remaining, width: width, height: available, font: font)
                    let index = remaining.index(remaining.startIndex, offsetBy: max(1, split))
                    let chunk = String(remaining[..<index])
                    let chunkHeight = textHeight(chunk, width: width, font: font)
                    draw(chunk, in: CGRect(x: margin, y: y, width: width, height: chunkHeight), font: font, color: color)
                    remaining = String(remaining[index...])
                    if !remaining.isEmpty {
                        beginPage()
                    } else {
                        y += chunkHeight + spacingAfter
                    }
                }
            }

            func addSectionTitle(_ title: String) {
                ensureSpace(34)
                y += 10
                addText(title, font: .boldSystemFont(ofSize: 16), spacingAfter: 7)
            }

            func addLabeledValue(_ label: String, value: String) {
                guard !value.isEmpty else { return }
                addText(
                    "\(label): \(value)",
                    font: .systemFont(ofSize: 11),
                    color: .black,
                    spacingAfter: 5
                )
            }

            func addDivider() {
                ensureSpace(10)
                UIColor.lightGray.setStroke()
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y + 3))
                path.addLine(to: CGPoint(x: pageRect.width - margin, y: y + 3))
                path.lineWidth = 0.5
                path.stroke()
                y += 10
            }

            beginPage()

            if let logoData, let logo = UIImage(data: logoData) {
                let maxSize = CGSize(width: 100, height: 60)
                let imageSize = aspectFitSize(image: logo.size, inside: maxSize)
                logo.draw(in: CGRect(x: margin, y: y, width: imageSize.width, height: imageSize.height))
                y += imageSize.height + 12
            }

            if let company, !company.name.isEmpty {
                addText(company.name, font: .boldSystemFont(ofSize: 13), spacingAfter: 3)
                let companyLines = [company.organizationNumber, company.address, company.phone, company.email]
                    .filter { !$0.isEmpty }
                for line in companyLines {
                    addText(line, font: .systemFont(ofSize: 9), color: .darkGray, spacingAfter: 2)
                }
                y += 8
            }

            addText(localized("Job report"), font: .boldSystemFont(ofSize: 26), spacingAfter: 12)
            if job.isSampleData {
                addText(
                    localized("Sample data – not a real customer or job"),
                    font: .boldSystemFont(ofSize: 12),
                    color: .systemRed,
                    spacingAfter: 12
                )
            }
            addLabeledValue(localized("Report date"), value: Date.now.formatted(.dateTime.day().month().year().locale(locale)))
            addLabeledValue(localized("Job number"), value: job.jobNumber)
            addLabeledValue(localized("Status"), value: localizedStatus(job.status))
            addLabeledValue(localized("Customer"), value: job.customer.name)
            addLabeledValue(localized("Work address"), value: job.workAddress)
            addLabeledValue(localized("Planned date"), value: job.plannedDate.formatted(.dateTime.day().month().year().locale(locale)))
            if let completedAt = job.completedAt {
                addLabeledValue(localized("Completed date"), value: completedAt.formatted(.dateTime.day().month().year().locale(locale)))
            }
            if !job.details.isEmpty {
                addSectionTitle(localized("Description"))
                addText(job.details, font: .systemFont(ofSize: 11))
            }

            if options.includesWorkLog, !job.workEntries.isEmpty {
                addSectionTitle(localized("Work log"))
                let entries = job.workEntries.sorted { $0.workDate < $1.workDate }
                for entry in entries {
                    ensureSpace(54)
                    addText(
                        entry.workDate.formatted(.dateTime.day().month().year().locale(locale)),
                        font: .boldSystemFont(ofSize: 11),
                        spacingAfter: 3
                    )
                    addText(entry.details, font: .systemFont(ofSize: 10), spacingAfter: 3)
                    addText(
                        EntryFormatting.duration(totalMinutes: entry.durationMinutes),
                        font: .systemFont(ofSize: 10),
                        color: .darkGray,
                        spacingAfter: 5
                    )
                    addDivider()
                }
                let total = job.workEntries.reduce(0) { $0 + $1.durationMinutes }
                addLabeledValue(localized("Total time"), value: EntryFormatting.duration(totalMinutes: total))
            }

            if options.includesMaterials, !job.materialEntries.isEmpty {
                addSectionTitle(localized("Materials"))
                let materials = job.materialEntries.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                for material in materials {
                    ensureSpace(46)
                    let quantity = EntryFormatting.formatDecimal(material.quantity, locale: locale)
                    let unit: String
                    if let predefined = MaterialUnit(rawValue: material.unit) {
                        unit = localizedUnit(predefined)
                    } else {
                        unit = material.unit
                    }
                    addText(material.name, font: .boldSystemFont(ofSize: 11), spacingAfter: 3)
                    let price = material.unitPrice.map {
                        " · " + PriceEstimateCalculator.currency($0, locale: locale)
                    } ?? ""
                    addText("\(quantity) \(unit)\(price)", font: .systemFont(ofSize: 10), spacingAfter: 3)
                    if !material.note.isEmpty {
                        addText(material.note, font: .systemFont(ofSize: 10), color: .darkGray, spacingAfter: 5)
                    }
                    addDivider()
                }
            }

            if options.includesPriceEstimate {
                let estimate = PriceEstimateCalculator.estimate(for: job)
                if estimate.subtotal > 0 {
                    addSectionTitle(localized("Price estimate"))
                    addLabeledValue(localized("Labor"), value: PriceEstimateCalculator.currency(estimate.labor, locale: locale))
                    addLabeledValue(localized("Materials"), value: PriceEstimateCalculator.currency(estimate.materials, locale: locale))
                    addLabeledValue(localized("Driving"), value: PriceEstimateCalculator.currency(estimate.driving, locale: locale))
                    addLabeledValue(localized("Subtotal excluding VAT"), value: PriceEstimateCalculator.currency(estimate.subtotal, locale: locale))
                    if job.vatRatePercent != nil {
                        addLabeledValue(localized("VAT"), value: PriceEstimateCalculator.currency(estimate.vat, locale: locale))
                    }
                    addLabeledValue(localized("Suggested total price"), value: PriceEstimateCalculator.currency(estimate.total, locale: locale))
                    addText(
                        localized("This is a non-binding price estimate, not an invoice or payment request."),
                        font: .italicSystemFont(ofSize: 9),
                        color: .darkGray
                    )
                }
            }

            if options.includesPhotos, !photoData.isEmpty {
                if let firstData = photoData.first?.1, let firstImage = UIImage(data: firstData) {
                    let maxSize = CGSize(width: pageRect.width - margin * 2, height: 310)
                    let firstSize = aspectFitSize(image: firstImage.size, inside: maxSize)
                    ensureSpace(firstSize.height + 100)
                } else {
                    ensureSpace(115)
                }
                addSectionTitle(localized("Photos"))
                for (photo, data) in photoData {
                    if let data, let image = UIImage(data: data) {
                        let maxSize = CGSize(width: pageRect.width - margin * 2, height: 310)
                        let size = aspectFitSize(image: image.size, inside: maxSize)
                        ensureSpace(size.height + 65)
                        addText(localizedCategory(photo.category), font: .boldSystemFont(ofSize: 12), spacingAfter: 5)
                        image.draw(in: CGRect(x: margin, y: y, width: size.width, height: size.height))
                        y += size.height + 7
                    } else {
                        ensureSpace(80)
                        addText(localizedCategory(photo.category), font: .boldSystemFont(ofSize: 12), spacingAfter: 5)
                        addText(localized("Image unavailable"), font: .italicSystemFont(ofSize: 10), color: .darkGray)
                    }
                    if !photo.caption.isEmpty {
                        addText(photo.caption, font: .systemFont(ofSize: 10), spacingAfter: 4)
                    }
                    addText(
                        localized("Registered") + ": " + photo.registeredAt.formatted(.dateTime.day().month().year().locale(locale)),
                        font: .systemFont(ofSize: 9),
                        color: .darkGray,
                        spacingAfter: 8
                    )
                    addDivider()
                }
            }

            finishPage()
        }
        return outputURL
    }

    private func makeOutputURL(jobNumber: String) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support
            .appending(path: "JobbBevis", directoryHint: .isDirectory)
            .appending(path: "Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let safeNumber = jobNumber.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return directory.appending(path: "JobbBevis-\(safeNumber)-\(date)-\(UUID().uuidString.prefix(8)).pdf")
    }

    nonisolated private func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        ceil((text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height)
    }

    nonisolated private func draw(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .natural
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style],
            context: nil
        )
    }

    nonisolated private func fittingPrefixLength(_ text: String, width: CGFloat, height: CGFloat, font: UIFont) -> Int {
        var lower = 1
        var upper = text.count
        while lower < upper {
            let middle = (lower + upper + 1) / 2
            let index = text.index(text.startIndex, offsetBy: middle)
            let prefix = String(text[..<index])
            if textHeight(prefix, width: width, font: font) <= height {
                lower = middle
            } else {
                upper = middle - 1
            }
        }
        return lower
    }

    nonisolated private func aspectFitSize(image: CGSize, inside bounds: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return .zero }
        let scale = min(bounds.width / image.width, bounds.height / image.height, 1)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
}
