//
//  JobbBevisCoreTests.swift
//  JobbBevisCoreTests
//
//  Created by Terje Moe on 25/10/2026.
//

import Testing
@testable import JobbBevis

struct JobbBevisCoreTests {

    @Test("Accounting CSV contains invoice lines and safely escaped values")
    @MainActor
    func accountingCSVExport() throws {
        #expect(try CoreTestSupport.accountingCSVContainsInvoiceLines())
    }

    @Test("Accounting report is generated as a PDF")
    @MainActor
    func accountingPDFReport() throws {
        #expect(try CoreTestSupport.accountingReportIsPDF())
    }

    @Test("Work and material entries can be deleted from a job")
    @MainActor
    func deleteWorkAndMaterialEntries() throws {
        #expect(try CoreTestSupport.workAndMaterialEntriesCanBeDeleted())
    }

}
