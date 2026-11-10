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
                    text: "Open Settings and export a backup regularly. Choose full restore or start fresh with customers, suppliers and products. After choosing the file, select Review selected backup to open the confirmation screen. You can export current data first and then continue with the selected file. Issued documents on this device are retained. A register import also keeps your company details and number sequences."
                )
                NavigationLink {
                    KitchenExampleView()
                } label: {
                    Label("Step by step: refresh a kitchen", systemImage: "list.number")
                }
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

private struct KitchenExampleView: View {
    var body: some View {
        List {
            Section { Text("Enter your company details in Settings and choose whether the company is VAT registered. For this example, use 25% VAT. Add the customer Olga Hansen under Customers. Add a supplier under Suppliers and create Sparkel (kg, 65 kr), wall paint (litres, 185 kr), parquet (m², 650 kr) and skirting boards (metres, 95 kr) in the product register. Prices are excluding VAT.") } header: { Text("1. Prepare the registers") }
            Section { Text("Create “Kitchen refresh at Olga”. Choose Olga, enter the work address and describe painting walls, laying parquet and fitting skirting boards. Enable Exercise job when practising. Use only fictional details for the exercise.") } header: { Text("2. Create the job") }
            Section { Text("Set estimated work to 38 hours and the hourly rate to 800 kr, with 25% VAT. In the purchase list add 10 kg filler, 10 litres paint, 23 m² parquet and 20 metres skirting boards. Create the bid PDF. If the customer accepts, record the accepted bid before starting work.") } header: { Text("3. Add the simple estimate") }
            Section { Text("Open Photos, take or choose a photo, select Before and enter “Kitchen before work”. Save the photo.") } header: { Text("4. Photograph before work") }
            Section { Text("In Work log add 8 hours with the description “Preparation and removal of old flooring”. Enter actual driving only if relevant.") } header: { Text("5. Register the first working day") }
            Section { Text("Open the purchase list and press the circle beside filler. In Quantity used now enter 2 and choose Register usage. Leave the planned quantity at 10 kg. Do not register the same consumption manually under Materials.") } header: { Text("6. Register partial consumption") }
            Section { Text("Add 18 hours in Work log with “Filled and painted walls and ceiling”. From the purchase list register another 8 kg filler and 10 litres paint. Add an Underway photo with a short caption.") } header: { Text("7. Finish painting") }
            Section { Text("Add 12 hours with “Laid parquet and fitted skirting boards”. Register 23 m² parquet and 20 metres skirting boards from the purchase list.") } header: { Text("8. Lay the floor") }
            Section { Text("Add an After photo and describe the finished kitchen. Open Edit on the job, choose Completed and set the actual completion date. The example totals 38 hours and 19,350 kr in materials, or 62,187.50 kr including VAT.") } header: { Text("9. Finish the job") }
            Section { Text("Choose Create report on the job. Include photos and captions, work log and materials. Leave Show prices off for a documentation report. Create the PDF and use Share to save it in Files or share it with the customer.") } header: { Text("10. Share the documentation") }
            Section { Text("Open Invoices and approval and choose the job. Create the draft, set the due date and choose Save draft. Use Preview draft to open the PDF. When ready, choose Approve and issue invoice. An exercise job creates an exercise invoice marked DO NOT PAY.") } header: { Text("11. Create the invoice") }
            Section { Text("Open Settings and choose Export backup. Save the file in Files in a safe location. Use Restore full backup to recover the complete contents, or Start fresh with registers to reuse only customers, suppliers and products without importing old jobs.") } header: { Text("12. Save a backup") }
        }
        .navigationTitle("Step by step: refresh a kitchen")
    }
}
