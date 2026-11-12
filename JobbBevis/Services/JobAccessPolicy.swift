import Foundation

/// Access decisions never change stored jobs or their status.
enum AppTier: String { case free, plus }

struct JobAccessPolicy {
    let tier: AppTier
    let selectedJobID: UUID?

    func activeJobs(in jobs: [JobRecord]) -> [JobRecord] {
        jobs.filter { !$0.isArchived && $0.status != .completed }
    }

    func editableJobID(in jobs: [JobRecord]) -> UUID? {
        let active = activeJobs(in: jobs)
        if let selectedJobID, active.contains(where: { $0.id == selectedJobID }) { return selectedJobID }
        return active.count == 1 ? active.first?.id : nil
    }

    func canCreateJob(in jobs: [JobRecord]) -> Bool {
        tier == .plus || activeJobs(in: jobs).isEmpty
    }

    func canEdit(_ job: JobRecord, in jobs: [JobRecord]) -> Bool {
        tier == .plus || (!job.isArchived && job.status != .completed && editableJobID(in: jobs) == job.id)
    }

    func canReopen(_ job: JobRecord, in jobs: [JobRecord]) -> Bool {
        tier == .plus || activeJobs(in: jobs).allSatisfy { $0.id == job.id }
    }

    func canSave(_ job: JobRecord?, status: JobStatus, in jobs: [JobRecord]) -> Bool {
        guard tier != .plus else { return true }
        guard let job else { return canCreateJob(in: jobs) }
        // Closed jobs are reopened explicitly before editing.
        return canEdit(job, in: jobs)
    }
}
