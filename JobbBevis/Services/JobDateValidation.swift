import Foundation

/// Calendar-day comparisons: times within the same day are not date conflicts.
enum JobDateValidation {
    enum Issue: String, Identifiable {
        case completionBeforePlanned, completionInFuture, workAfterCompletion, futureWork, deliveryInFuture, dueBeforeIssue, dueBeforeDelivery
        var id: String { rawValue }
        var message: LocalizedStringResource {
            switch self {
            case .completionBeforePlanned: "Completion is earlier than the planned date."
            case .completionInFuture: "The completion date is in the future."
            case .workAfterCompletion: "Work is registered after the completion date."
            case .futureWork: "The work log contains future dates."
            case .deliveryInFuture: "The delivery date is later than today."
            case .dueBeforeIssue: "The due date is earlier than the invoice date."
            case .dueBeforeDelivery: "The due date is earlier than the delivery date."
            }
        }
    }
    static func issues(plannedDate: Date, completedAt: Date?, workDates: [Date], dueDate: Date? = nil, checksDelivery: Bool = false, now: Date = .now, calendar: Calendar = .current) -> [Issue] {
        func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }
        var result: [Issue] = []
        if let completedAt {
            if day(completedAt) < day(plannedDate) { result.append(.completionBeforePlanned) }
            if day(completedAt) > day(now) { result.append(.completionInFuture) }
            if workDates.contains(where: { day($0) > day(completedAt) }) { result.append(.workAfterCompletion) }
        }
        if workDates.contains(where: { day($0) > day(now) }) { result.append(.futureWork) }
        let delivery = completedAt ?? plannedDate
        if checksDelivery && day(delivery) > day(now) { result.append(.deliveryInFuture) }
        if let dueDate {
            if day(dueDate) < day(now) { result.append(.dueBeforeIssue) }
            if day(dueDate) < day(delivery) { result.append(.dueBeforeDelivery) }
        }
        return result
    }
    static func issues(for job: JobRecord, dueDate: Date? = nil, checksDelivery: Bool = false, now: Date = .now) -> [Issue] {
        issues(plannedDate: job.plannedDate, completedAt: job.completedAt, workDates: job.workEntries.map(\.workDate), dueDate: dueDate, checksDelivery: checksDelivery, now: now)
    }
}
