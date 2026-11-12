import SwiftUI
import SwiftData

struct PlusView: View {
    @Environment(AccessStore.self) private var access
    var body: some View {
        List {
            Section {
                Label(access.hasPlus ? "JobbBevis Plus" : "JobbBevis Free", systemImage: "checkmark.seal")
                Text("Your jobs, photos, invoices and reports are kept when your access changes.")
            }
            Section("Included for free") {
                Label("One active job at a time", systemImage: "hammer")
                Text("Complete your current job to create the next one for free. You can still read and export completed jobs.")
                    .font(.footnote).foregroundStyle(.secondary)
                Label("Unlimited customers, work entries, materials and photos", systemImage: "photo.on.rectangle")
                Label("PDF reports, sharing and printing without a watermark", systemImage: "doc.richtext")
                Label("Backup and restore", systemImage: "externaldrive")
                Label("Read and export earlier jobs and issued documents", systemImage: "archivebox")
            }
            Section("Included with Plus") {
                Label("Unlimited active jobs", systemImage: "hammer.fill")
                Label("Invoices and credit notes", systemImage: "doc.text")
                Label("Accounting export and summary reports", systemImage: "chart.bar.doc.horizontal")
                Label("Reusable product catalog and prices", systemImage: "shippingbox")
            }
            Section("Get Plus") {
                if access.hasPlus {
                    Label("Plus is unlocked", systemImage: "checkmark.seal.fill")
                } else if access.isCheckingPurchases {
                    ProgressView("Checking purchases…")
                } else if let product = access.product {
                    Button {
                        Task { await access.buyPlus() }
                    } label: {
                        Text("Unlock Plus · \(product.displayPrice)")
                    }
                    .disabled(!access.canPurchase)
                    Text("One-time purchase. No subscription. The final price is shown in Apple's purchase confirmation.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if access.isLoadingProduct {
                    ProgressView("Loading price…")
                } else {
                    Text("Plus is currently unavailable. Please try again later.")
                    Button("Reload price") { Task { await access.loadProduct() } }
                        .disabled(access.isBusy)
                }
                Button("Restore purchases") { Task { await access.restorePurchases() } }
                    .disabled(access.isBusy)
                if access.isBusy { ProgressView("Contacting Apple…") }
                if let message = access.message { Text(message).font(.footnote) }
                if let error = access.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            #if DEBUG
            Section("Development testing") {
                Picker("Test access", selection: Binding(get: { access.testTierSelection }, set: { access.selectTestTier($0) })) {
                    Text("Apple purchases").tag("apple")
                    Text("Free").tag(AppTier.free.rawValue)
                    Text("Plus").tag(AppTier.plus.rawValue)
                }
                Text("For this development session only. No purchase is made. Release builds do not include this control.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            #endif
        }
        .navigationTitle("JobbBevis Plus")
    }
}

/// Use at every entry point to a paid destination, including Settings links.
struct PlusFeatureView<Content: View>: View {
    @Environment(AccessStore.self) private var access
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content
    var body: some View {
        if access.hasPlus { content() }
        else {
            ContentUnavailableView {
                Label(title, systemImage: "lock")
            } description: {
                Text("This feature requires JobbBevis Plus. Your existing data is kept. Job PDF reports and backup remain free.")
            } actions: {
                NavigationLink("See Free and Plus") { PlusView() }
            }
        }
    }
}

private struct CanEditJobKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var canEditJob: Bool {
        get { self[CanEditJobKey.self] }
        set { self[CanEditJobKey.self] = newValue }
    }
}

struct PlusSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            PlusView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct FreeAccessStatusView: View {
    @Environment(AccessStore.self) private var access
    let jobs: [JobRecord]
    @State private var showsPlus = false
    var body: some View {
        if !access.hasPlus {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Free: one active job").font(.subheadline.bold())
                    Spacer()
                    Button("Plus") { showsPlus = true }
                }
                if access.policy.activeJobs(in: jobs).count > 1 && access.policy.editableJobID(in: jobs) == nil {
                    Text("All jobs are kept. Choose the one to edit for free. Complete it before choosing another.")
                        .font(.footnote)
                    Menu("Choose active job") {
                        ForEach(access.policy.activeJobs(in: jobs)) { job in
                            Button("\(job.jobNumber) · \(job.title)") { access.selectedJobID = job.id }
                        }
                    }
                } else if let id = access.policy.editableJobID(in: jobs), let job = jobs.first(where: { $0.id == id }) {
                    Text("\(job.jobNumber) · \(job.title)").font(.footnote).lineLimit(2)
                }
            }
            .padding(12).background(.regularMaterial)
            .sheet(isPresented: $showsPlus) { PlusSheet() }
        }
    }
}

/// NavigationStack destinations resolve access from the current jobs instead of
/// relying on the environment of the NavigationLink label or its List section.
private struct JobEditingAccessModifier: ViewModifier {
    @Environment(AccessStore.self) private var access
    @Query private var jobs: [JobRecord]
    let job: JobRecord
    func body(content: Content) -> some View {
        content.environment(\.canEditJob, access.policy.canEdit(job, in: jobs))
    }
}

extension View {
    func jobEditingAccess(for job: JobRecord) -> some View {
        modifier(JobEditingAccessModifier(job: job))
    }
}
