import SwiftData
import SwiftUI

private enum JobFilter: String, CaseIterable, Identifiable {
    case active
    case all
    case planned
    case inProgress
    case completed
    case archived

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .all: "All"
        case .planned: "Planned"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }

    func includes(_ job: JobRecord) -> Bool {
        switch self {
        case .active:
            !job.isArchived && job.status != .completed
        case .all:
            !job.isArchived
        case .planned:
            !job.isArchived && job.status == .planned
        case .inProgress:
            !job.isArchived && job.status == .inProgress
        case .completed:
            !job.isArchived && job.status == .completed
        case .archived:
            job.isArchived
        }
    }
}

struct JobsView: View {
    @Query(sort: \JobRecord.plannedDate) private var jobs: [JobRecord]
    @State private var searchText = ""
    @State private var filter = JobFilter.active
    @State private var isAddingJob = false

    private var filteredJobs: [JobRecord] {
        jobs.filter { job in
            filter.includes(job)
                && (searchText.isEmpty
                    || job.title.localizedStandardContains(searchText)
                    || job.jobNumber.localizedStandardContains(searchText)
                    || job.customer.name.localizedStandardContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if jobs.isEmpty {
                    JobEmptyState(addJob: { isAddingJob = true })
                } else if filteredJobs.isEmpty {
                    FilteredJobsEmptyState(searchText: searchText)
                } else {
                    List(filteredJobs) { job in
                        NavigationLink {
                            JobDetailView(job: job)
                        } label: {
                            JobRowView(job: job)
                        }
                    }
                }
            }
            .navigationTitle("Jobs")
            .searchable(text: $searchText, prompt: "Search jobs")
            .toolbar {
                ToolbarItem {
                    Menu {
                        Picker("Filter", selection: $filter) {
                            ForEach(JobFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem {
                    Button("New job", systemImage: "plus") {
                        isAddingJob = true
                    }
                }
            }
            .sheet(isPresented: $isAddingJob) {
                JobFormView()
            }
        }
    }
}

private struct JobEmptyState: View {
    let addJob: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No jobs", systemImage: "hammer")
        } description: {
            Text("Create your first job and connect it to a customer.")
        } actions: {
            Button("New job", systemImage: "plus", action: addJob)
        }
    }
}

private struct FilteredJobsEmptyState: View {
    let searchText: String

    var body: some View {
        if searchText.isEmpty {
            ContentUnavailableView {
                Label("No matching jobs", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Choose another status filter.")
            }
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}
