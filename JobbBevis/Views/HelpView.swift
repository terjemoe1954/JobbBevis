import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section {
                HelpTopic(
                    symbol: "briefcase",
                    title: "Jobs",
                    text: "Create a job, choose a customer, and add work, materials, and photos as the job progresses. You can reopen a completed job and update it when needed."
                )
                HelpTopic(
                    symbol: "doc.richtext",
                    title: "Reports",
                    text: "Open a job and choose Create report. Select the content to include, preview the PDF, and then share, save, or print it."
                )
                HelpTopic(
                    symbol: "externaldrive",
                    title: "Backup",
                    text: "Open Settings and export a backup regularly. Import first checks the file and shows a summary. Existing data is only replaced after you confirm."
                )
            } footer: {
                Text("JobbBevis stores job information and photos locally on this device. The primary workflow works without an internet connection.")
            }
        }
        .navigationTitle("Help")
    }
}

private struct HelpTopic: View {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}
