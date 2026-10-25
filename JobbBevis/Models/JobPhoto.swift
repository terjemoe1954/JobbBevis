import Foundation
import SwiftData

enum PhotoCategory: String, CaseIterable, Identifiable {
    case before
    case during
    case after

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .before: "Before"
        case .during: "During"
        case .after: "After"
        }
    }
}

@Model
final class JobPhoto {
    @Attribute(.unique) var id: UUID
    var relativePath: String
    var categoryRawValue: String
    var caption: String
    var registeredAt: Date
    var sortOrder: Int
    var job: JobRecord

    var category: PhotoCategory {
        get { PhotoCategory(rawValue: categoryRawValue) ?? .during }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        relativePath: String,
        category: PhotoCategory,
        caption: String = "",
        registeredAt: Date = .now,
        sortOrder: Int,
        job: JobRecord
    ) {
        self.id = id
        self.relativePath = relativePath
        self.categoryRawValue = category.rawValue
        self.caption = caption
        self.registeredAt = registeredAt
        self.sortOrder = sortOrder
        self.job = job
    }
}
