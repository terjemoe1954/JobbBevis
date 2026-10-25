import SwiftData
import UIKit

@MainActor
struct SampleDataService {
    func hasSampleData(in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<JobRecord>(
            predicate: #Predicate { $0.sampleDataMarker == true }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    func load(in context: ModelContext) async throws {
        guard try !hasSampleData(in: context) else {
            throw SampleDataError.alreadyLoaded
        }

        let now = Date.now
        let calendar = Calendar.current
        let samples = [
            SampleDefinition(
                customerName: "Eksempelkunde Solsiden",
                title: "Reparasjon av terrasse",
                address: "Eksempelveien 1",
                details: "Fiktivt oppdrag: skifte tre skadde terrassebord og kontrollere innfesting.",
                status: .completed,
                daysFromToday: -8,
                work: "Skiftet terrassebord og etterstrammet festemidler.",
                minutes: 210,
                material: ("Terrassebord", 3, "pcs"),
                symbol: "hammer.fill",
                color: UIColor.systemBrown,
                caption: "Illustrasjon av ferdig terrassereparasjon"
            ),
            SampleDefinition(
                customerName: "Eksempelkunde Fargeglad",
                title: "Maling av rom",
                address: "Demogata 2",
                details: "Fiktivt oppdrag: klargjøring og maling av ett rom.",
                status: .inProgress,
                daysFromToday: 1,
                work: "Dekking, sparkling og første strøk.",
                minutes: 270,
                material: ("Veggmaling", 5, "l"),
                symbol: "paintbrush.fill",
                color: UIColor.systemIndigo,
                caption: "Illustrasjon av malearbeid"
            ),
            SampleDefinition(
                customerName: "Eksempelkunde Verkstedet",
                title: "Generell service",
                address: "Testplassen 3",
                details: "Fiktivt oppdrag: enkel kontroll, justering og funksjonstest.",
                status: .planned,
                daysFromToday: 5,
                work: "Innledende kontroll og registrering.",
                minutes: 45,
                material: ("Smøremiddel", 1, "package"),
                symbol: "wrench.and.screwdriver.fill",
                color: UIColor.systemTeal,
                caption: "Illustrasjon av generell service"
            )
        ]

        var createdPaths: [String] = []
        do {
            for (index, sample) in samples.enumerated() {
                let customer = Customer(
                    name: sample.customerName,
                    address: sample.address,
                    isSampleData: true
                )
                let plannedDate = calendar.date(
                    byAdding: .day,
                    value: sample.daysFromToday,
                    to: now
                ) ?? now
                let job = JobRecord(
                    jobNumber: "DEMO-\(index + 1)",
                    title: sample.title,
                    customer: customer,
                    workAddress: sample.address,
                    details: sample.details,
                    plannedDate: plannedDate,
                    status: sample.status,
                    isSampleData: true
                )
                let path = try await PhotoFileStore().importImageData(
                    illustration(symbol: sample.symbol, color: sample.color),
                    jobID: job.id
                )
                createdPaths.append(path)

                job.workEntries.append(
                    WorkEntry(
                        workDate: plannedDate,
                        details: sample.work,
                        durationMinutes: sample.minutes,
                        job: job
                    )
                )
                job.materialEntries.append(
                    MaterialEntry(
                        name: sample.material.0,
                        quantity: Decimal(sample.material.1),
                        unit: sample.material.2,
                        note: "Fiktivt eksempel",
                        job: job
                    )
                )
                job.photos.append(
                    JobPhoto(
                        relativePath: path,
                        category: sample.status == .completed ? .after : .during,
                        caption: sample.caption,
                        registeredAt: plannedDate,
                        sortOrder: 0,
                        job: job
                    )
                )
                context.insert(customer)
                context.insert(job)
            }
            try context.save()
        } catch {
            for path in createdPaths {
                try? PhotoFileStore().remove(relativePath: path)
            }
            context.rollback()
            throw error
        }
    }

    func remove(in context: ModelContext) throws {
        let jobs = try context.fetch(
            FetchDescriptor<JobRecord>(predicate: #Predicate { $0.sampleDataMarker == true })
        )
        let customers = try context.fetch(
            FetchDescriptor<Customer>(predicate: #Predicate { $0.sampleDataMarker == true })
        )

        for job in jobs {
            try PhotoFileStore().removeAll(for: job)
            context.delete(job)
        }
        try context.save()
        for customer in customers {
            context.delete(customer)
        }
        try context.save()
    }

    private func illustration(symbol: String, color: UIColor) throws -> Data {
        let size = CGSize(width: 1_200, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.withAlphaComponent(0.18).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            color.withAlphaComponent(0.35).setFill()
            context.fill(CGRect(x: 0, y: 590, width: size.width, height: 210))

            let configuration = UIImage.SymbolConfiguration(pointSize: 260, weight: .regular)
            let symbolImage = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
            symbolImage?.draw(
                in: CGRect(x: 440, y: 190, width: 320, height: 320),
                blendMode: .normal,
                alpha: 1
            )
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw SampleDataError.imageCreationFailed
        }
        return data
    }
}

private struct SampleDefinition {
    let customerName: String
    let title: String
    let address: String
    let details: String
    let status: JobStatus
    let daysFromToday: Int
    let work: String
    let minutes: Int
    let material: (String, Int, String)
    let symbol: String
    let color: UIColor
    let caption: String
}

enum SampleDataError: LocalizedError {
    case alreadyLoaded
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .alreadyLoaded:
            String(localized: "Sample jobs are already loaded.")
        case .imageCreationFailed:
            String(localized: "The sample image could not be created.")
        }
    }
}
