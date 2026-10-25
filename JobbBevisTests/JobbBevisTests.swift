import Foundation
import Testing
import JobbBevis

@Suite("JobbBevis core behavior")
struct JobbBevisTests {
    @Test("Duration formatting handles hours and minutes")
    @MainActor
    func durationFormatting() {
        #expect(CoreTestSupport.formattedDuration(totalMinutes: 0) == String(localized: "0 min"))
        #expect(CoreTestSupport.formattedDuration(totalMinutes: 60) == String(localized: "1 h"))
        #expect(CoreTestSupport.formattedDuration(totalMinutes: 135) == String(localized: "2 h 15 min"))
    }

    @Test("Job numbers are unique and sequential")
    @MainActor
    func jobNumbers() throws {
        let numbers = try CoreTestSupport.nextJobNumbers()
        #expect(numbers == ["JB-0001", "JB-0002"])
        #expect(Set(numbers).count == numbers.count)
    }

    @Test("Stored relationships retain work and materials")
    @MainActor
    func persistenceRelationships() throws {
        #expect(try CoreTestSupport.relationshipsPersist())
    }

    @Test("Backup round trip preserves relationships and sample flags")
    @MainActor
    func backupRoundTrip() throws {
        #expect(try CoreTestSupport.backupRoundTripPreservesData())
    }
}
