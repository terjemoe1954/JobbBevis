import SwiftData
import SwiftUI

struct AccountingTransferView: View {
    @Query(sort: \InvoiceRecord.issuedAt, order: .reverse) private var invoices: [InvoiceRecord]

    var body: some View {
        NavigationStack {
            List {
                Section("Accounting systems") {
                    AccountingSystemRow(name: "Fiken")
                    AccountingSystemRow(name: "Conta")
                    AccountingSystemRow(name: "Tripletex")
                    AccountingSystemRow(name: "DNB Regnskap")
                    AccountingSystemRow(name: "PowerOffice Go")
                }

                Section("Ready for transfer") {
                    LabeledContent("Approved invoices", value: "\(invoices.count)")
                    Text("Choose an accounting system when a direct connection or file export has been configured. Approved invoice snapshots remain unchanged in JobbBevis.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Transfer to accounting")
        }
    }
}

private struct AccountingSystemRow: View {
    let name: String

    var body: some View {
        Label(name, systemImage: "building.columns")
    }
}
