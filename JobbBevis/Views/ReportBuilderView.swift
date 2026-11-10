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
    @State private var includesPriceEstimate = true
    @State private var showsPrices = false
    @State private var isGenerating = false
    @State private var preview: ReportPreview?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if job.isExercise {
                    Section { Text("EXERCISE - DO NOT PAY").foregroundStyle(.orange) }
                }
                let dateIssues = JobDateValidation.issues(for: job)
                if !dateIssues.isEmpty {
                    Section("Check dates") { ForEach(dateIssues) { Text($0.message).foregroundStyle(.orange) } }
                }
                Section("Include in report") {
                    Toggle("Photos", isOn: $includesPhotos)
                    Toggle("Work log", isOn: $includesWorkLog)
                    Toggle("Materials", isOn: $includesMaterials)
                    Toggle("Show prices", isOn: $showsPrices)
                    if showsPrices {
                        Toggle("Include financial summary", isOn: $includesPriceEstimate)
                    }
                    Text("Show prices controls generated price fields. Text you wrote in descriptions, notes and captions is included unchanged.")
                        .font(.footnote).foregroundStyle(.secondary)
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
                    if showsPrices && includesPriceEstimate {
                        ReportSummaryRow(
                            title: "Registered so far",
                            value: PriceEstimateCalculator.currency(
                                PriceEstimateCalculator.summary(for: job, basis: .registered, isVATRegistered: profiles.first?.isVATRegistered ?? false).total,
                                locale: locale
                            ),
                            isIncluded: true
                        )
                    }

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
                    includesMaterials: includesMaterials,
                    includesPriceEstimate: includesPriceEstimate,
                    showsPrices: showsPrices
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
