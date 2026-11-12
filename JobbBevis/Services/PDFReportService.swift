import Foundation
import SwiftUI
import UIKit

struct ReportOptions {
    var includesPhotos = true
    var includesWorkLog = true
    var includesMaterials = true
    var includesPriceEstimate = true
    var showsPrices = false
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
                String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), locale: locale))
            }

            func duration(_ minutes: Int) -> String {
                let value = max(0, minutes)
                let hours = value / 60
                let remainder = value % 60
                if hours == 0 { return "\(remainder) min" }
                let hourLabel = localized("h")
                return remainder == 0 ? "\(hours) \(hourLabel)" : "\(hours) \(hourLabel) \(remainder) min"
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
                case .package: localized("package")
                case .bucket: localized("spann")
                case .box: localized("eske")
                case .set: localized("sett")
                case .roll: localized("rull")
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
                if job.isExercise {
                    draw(localized("EXERCISE - DO NOT PAY"), in: CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 24), font: .boldSystemFont(ofSize: 13), color: .systemRed)
                    y += 30
                }
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
                let usableHeight = pageRect.height - margin * 2 - footerHeight - (job.isExercise ? 30 : 0) - spacingAfter

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

            func addSectionTitle(_ title: String, minimumSpace: CGFloat = 34) {
                ensureSpace(minimumSpace)
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
                addSectionTitle(localized("Work log"), minimumSpace: options.showsPrices ? 180 : 115)
                let entries = job.workEntries.sorted { $0.workDate < $1.workDate }
                for entry in entries {
                    ensureSpace(options.showsPrices ? 145 : 80)
                    addText(
                        entry.workDate.formatted(.dateTime.day().month().year().locale(locale)),
                        font: .boldSystemFont(ofSize: 11),
                        spacingAfter: 3
                    )
                    addText(entry.details, font: .systemFont(ofSize: 10), spacingAfter: 3)
                    addText(
                        duration(entry.durationMinutes),
                        font: .systemFont(ofSize: 10),
                        color: .darkGray,
                        spacingAfter: 5
                    )
                    if options.showsPrices {
                        if let rate = job.hourlyRate {
                            addLabeledValue(localized("Hourly rate excluding VAT"), value: PriceEstimateCalculator.currency(rate, locale: locale))
                            let amount = Decimal(max(0, entry.durationMinutes)) / 60 * max(0, rate)
                            addLabeledValue(localized("Work amount excluding VAT"), value: PriceEstimateCalculator.currency(amount, locale: locale))
                        } else {
                            addText(localized("No price registered"), font: .italicSystemFont(ofSize: 10), color: .darkGray)
                        }
                    }
                    if let kilometers = entry.drivingKilometers, kilometers > 0 {
                        addLabeledValue(localized("Driving"), value: EntryFormatting.formatDecimal(kilometers, locale: locale) + " km")
                        if options.showsPrices, let rate = job.drivingRatePerKilometer {
                            addLabeledValue(localized("Driving amount excluding VAT"), value: PriceEstimateCalculator.currency(kilometers * max(0, rate), locale: locale))
                        }
                    }
                    addDivider()
                }
                let total = job.workEntries.reduce(0) { $0 + $1.durationMinutes }
                addLabeledValue(localized("Total time"), value: duration(total))
            }

            if options.includesMaterials, !job.materialEntries.isEmpty {
                addSectionTitle(localized("Registered materials and purchased services"), minimumSpace: options.showsPrices ? 150 : 100)
                let materials = job.materialEntries.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                for material in materials {
                    ensureSpace(options.showsPrices ? 115 : 65)
                    let quantity = EntryFormatting.formatDecimal(material.quantity, locale: locale)
                    let unit: String
                    if let predefined = MaterialUnit(rawValue: material.unit) {
                        unit = localizedUnit(predefined)
                    } else {
                        unit = material.unit
                    }
                    addText(material.displayName, font: .boldSystemFont(ofSize: 11), spacingAfter: 3)
                    addText("\(quantity) \(unit)", font: .systemFont(ofSize: 10), spacingAfter: 3)
                    if options.showsPrices {
                        if let price = material.unitPrice {
                            addLabeledValue(localized("Unit price excluding VAT"), value: PriceEstimateCalculator.currency(price, locale: locale))
                            addLabeledValue(localized("Line total excluding VAT"), value: PriceEstimateCalculator.currency(material.quantity * price, locale: locale))
                        } else {
                            addText(localized("No price registered"), font: .italicSystemFont(ofSize: 10), color: .darkGray)
                        }
                    }
                    if !material.note.isEmpty {
                        addText(material.note, font: .systemFont(ofSize: 10), color: .darkGray, spacingAfter: 5)
                    }
                    addDivider()
                }
            }

            if options.showsPrices && options.includesMaterials && !job.materialEntries.isEmpty {
                let materialsTotal = job.materialEntries.reduce(Decimal.zero) { $0 + $1.quantity * max(0, $1.unitPrice ?? 0) }
                addLabeledValue(localized("Priced materials and services excluding VAT"), value: PriceEstimateCalculator.currency(materialsTotal, locale: locale))
                if job.materialEntries.contains(where: { $0.unitPrice == nil }) {
                    addText(localized("Unpriced entries are not included in monetary totals."), font: .italicSystemFont(ofSize: 9), color: .darkGray)
                }
            }

            if options.showsPrices && options.includesPriceEstimate {
                func summary(_ title: String, _ estimate: PriceEstimate) {
                    ensureSpace(190)
                    addSectionTitle(localized(title))
                    addLabeledValue(localized("Own work"), value: PriceEstimateCalculator.currency(estimate.labor, locale: locale))
                    addLabeledValue(localized("Materials and purchased services"), value: PriceEstimateCalculator.currency(estimate.materials, locale: locale))
                    addLabeledValue(localized("Driving"), value: PriceEstimateCalculator.currency(estimate.driving, locale: locale))
                    addLabeledValue(localized("Subtotal excluding VAT"), value: PriceEstimateCalculator.currency(estimate.subtotal, locale: locale))
                    addLabeledValue(localized("VAT"), value: PriceEstimateCalculator.currency(estimate.vat, locale: locale))
                    addLabeledValue(localized("Total"), value: PriceEstimateCalculator.currency(estimate.total, locale: locale))
                }
                summary("Bid basis (planned)", PriceEstimateCalculator.summary(for: job, basis: .estimate, isVATRegistered: company?.isVATRegistered ?? false))
                summary("Registered so far", PriceEstimateCalculator.summary(for: job, basis: .registered, isVATRegistered: company?.isVATRegistered ?? false))
                if company?.isVATRegistered == true && job.vatRatePercent == nil {
                    addText(localized("No VAT rate is registered. Totals must be checked."), font: .italicSystemFont(ofSize: 10), color: .darkGray)
                }
                addText(localized("This is a job report, not an invoice or payment request."), font: .italicSystemFont(ofSize: 9), color: .darkGray)
            }

            if options.includesPhotos, !photoData.isEmpty {
                let gap: CGFloat = 16
                let columnWidth = (pageRect.width - margin * 2 - gap) / 2
                let categoryFont = UIFont.boldSystemFont(ofSize: 12)
                let captionFont = UIFont.systemFont(ofSize: 10)
                let dateFont = UIFont.systemFont(ofSize: 9)
                let usableHeight = pageRect.height - margin * 2 - footerHeight - (job.isExercise ? 30 : 0)

                func registeredText(_ photo: JobPhoto) -> String {
                    localized("Registered") + ": " + photo.registeredAt.formatted(.dateTime.day().month().year().locale(locale))
                }

                func blockHeight(_ photo: JobPhoto, image: UIImage?, width: CGFloat) -> CGFloat {
                    let imageHeight = image.map {
                        aspectFitSize(image: $0.size, inside: CGSize(width: width, height: 260)).height
                    } ?? textHeight(localized("Image unavailable"), width: width, font: captionFont)
                    let captionHeight = photo.caption.isEmpty ? 0 : textHeight(photo.caption, width: width, font: captionFont) + 4
                    return textHeight(localizedCategory(photo.category), width: width, font: categoryFont) + 5
                        + imageHeight + 7 + captionHeight
                        + textHeight(registeredText(photo), width: width, font: dateFont) + 18
                }

                let photos = photoData.map { (photo: $0.0, image: $0.1.flatMap { UIImage(data: $0) }) }
                let firstHeight = photos.prefix(2).map {
                    blockHeight($0.photo, image: $0.image, width: columnWidth)
                }.max() ?? 0
                ensureSpace(min(firstHeight, 400) + 40)
                addSectionTitle(localized("Photos"))
                var index = 0
                while index < photos.count {
                    let row = Array(photos[index..<min(index + 2, photos.count)])
                    let rowHeight = row.map {
                        blockHeight($0.photo, image: $0.image, width: columnWidth)
                    }.max() ?? 0

                    // Exceptionally long captions use the normal paginated text flow.
                    // No fixed-height caption box may discard part of the text.
                    if rowHeight > usableHeight {
                        let item = photos[index]
                        let size = item.image.map {
                            aspectFitSize(image: $0.size, inside: CGSize(width: pageRect.width - margin * 2, height: 310))
                        } ?? .zero
                        ensureSpace(size.height + 65)
                        addText(localizedCategory(item.photo.category), font: categoryFont, spacingAfter: 5)
                        if let image = item.image {
                            image.draw(in: CGRect(x: margin, y: y, width: size.width, height: size.height))
                            y += size.height + 7
                        } else {
                            addText(localized("Image unavailable"), font: .italicSystemFont(ofSize: 10), color: .darkGray)
                        }
                        addText(item.photo.caption, font: captionFont, spacingAfter: 4)
                        addText(registeredText(item.photo), font: dateFont, color: .darkGray, spacingAfter: 8)
                        addDivider()
                        index += 1
                        continue
                    }

                    ensureSpace(rowHeight)
                    let rowTop = y
                    for (column, item) in row.enumerated() {
                        let x = margin + CGFloat(column) * (columnWidth + gap)
                        var cardY = rowTop
                        func cardText(_ text: String, font: UIFont, color: UIColor = .black, spacing: CGFloat) {
                            guard !text.isEmpty else { return }
                            let height = textHeight(text, width: columnWidth, font: font)
                            draw(text, in: CGRect(x: x, y: cardY, width: columnWidth, height: height), font: font, color: color)
                            cardY += height + spacing
                        }
                        cardText(localizedCategory(item.photo.category), font: categoryFont, spacing: 5)
                        if let image = item.image {
                            let size = aspectFitSize(image: image.size, inside: CGSize(width: columnWidth, height: 260))
                            image.draw(in: CGRect(x: x + (columnWidth - size.width) / 2, y: cardY, width: size.width, height: size.height))
                            cardY += size.height + 7
                        } else {
                            cardText(localized("Image unavailable"), font: captionFont, color: .darkGray, spacing: 7)
                        }
                        cardText(item.photo.caption, font: captionFont, spacing: 4)
                        cardText(registeredText(item.photo), font: dateFont, color: .darkGray, spacing: 8)
                        UIColor.lightGray.setStroke()
                        let line = UIBezierPath()
                        line.move(to: CGPoint(x: x, y: rowTop + rowHeight - 7))
                        line.addLine(to: CGPoint(x: x + columnWidth, y: rowTop + rowHeight - 7))
                        line.lineWidth = 0.5
                        line.stroke()
                    }
                    y = rowTop + rowHeight
                    index += row.count
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
