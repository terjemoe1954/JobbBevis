import SwiftData
import SwiftUI

struct ReportBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Query private var profiles: [CompanyProfile]
    let job: JobRecord

    @State private var includesPhotos = true
    @State private var includesWorkLog = true
    @State private var includesMaterials = true
    @State private var isGenerating = false
    @State private var preview: ReportPreview?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Include in report") {
                    Toggle("Photos", isOn: $includesPhotos)
                    Toggle("Work log", isOn: $includesWorkLog)
                    Toggle("Materials", isOn: $includesMaterials)
                }

                Section {
                    ReportSummaryRow(
                        title: "Photos",
                        value: "\(job.photos.count)",
                        isIncluded: includesPhotos
                    )
                    ReportSummaryRow(
                        title: "Work entries",
                        value: "\(job.workEntries.count)",
                        isIncluded: includesWorkLog
                    )
                    ReportSummaryRow(
                        title: "Materials",
                        value: "\(job.materialEntries.count)",
                        isIncluded: includesMaterials
                    )
                } header: {
                    Text("Report contents")
                } footer: {
                    Text("Empty sections are omitted automatically. The exported PDF is a snapshot and will not change when the job is edited.")
                }

                Section {
                    Button("Generate preview", systemImage: "doc.richtext", action: generate)
                        .disabled(isGenerating)
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating report…")
                        }
                    }
                }
            }
            .navigationTitle("Create report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $preview) { preview in
                PDFPreviewView(pdfURL: preview.url)
            }
            .alert("Could not generate report", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func generate() {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let url = try PDFReportService().generate(
                job: job,
                company: profiles.first,
                options: ReportOptions(
                    includesPhotos: includesPhotos,
                    includesWorkLog: includesWorkLog,
                    includesMaterials: includesMaterials
                ),
                locale: locale
            )
            preview = ReportPreview(url: url)
        } catch {
            errorMessage = String(localized: "The report could not be generated. Try again.")
        }
    }
}

private struct ReportPreview: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ReportSummaryRow: View {
    let title: LocalizedStringResource
    let value: String
    let isIncluded: Bool

    var body: some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(isIncluded ? .green : .secondary)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
