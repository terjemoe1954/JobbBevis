import Foundation
import SwiftData

enum JobNumberService {
    static func nextNumber(in context: ModelContext) throws -> String {
        let descriptor = FetchDescriptor<AppMetadata>(
            predicate: #Predicate { $0.id == "main" }
        )
        let metadata: AppMetadata
        if let existing = try context.fetch(descriptor).first {
            metadata = existing
        } else {
            metadata = AppMetadata()
            context.insert(metadata)
        }

        let sequence = metadata.nextJobSequence
        metadata.nextJobSequence += 1
        return "JB-\(String(format: "%04d", sequence))"
    }
}
