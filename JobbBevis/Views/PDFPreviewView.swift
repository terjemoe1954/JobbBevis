import PDFKit
import SwiftUI
import UIKit

struct PDFPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let pdfURL: URL
    @State private var showPrintController = false

    var body: some View {
        NavigationStack {
            PDFDocumentView(url: pdfURL)
                .navigationTitle("Report preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        ShareLink(item: pdfURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button("Print", systemImage: "printer") {
                            showPrintController = true
                        }
                    }
                }
                .sheet(isPresented: $showPrintController) {
                    PrintPresenter(pdfURL: pdfURL) {
                        showPrintController = false
                    }
                    .ignoresSafeArea()
                }
        }
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}

private struct PrintPresenter: UIViewControllerRepresentable {
    let pdfURL: URL
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> PrintPresenterController {
        PrintPresenterController(pdfURL: pdfURL, onFinish: onFinish)
    }

    func updateUIViewController(_ uiViewController: PrintPresenterController, context: Context) {
    }
}

private final class PrintPresenterController: UIViewController {
    private let pdfURL: URL
    private let onFinish: () -> Void
    private var hasPresented = false

    init(pdfURL: URL, onFinish: @escaping () -> Void) {
        self.pdfURL = pdfURL
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresented else { return }
        hasPresented = true

        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = pdfURL.deletingPathExtension().lastPathComponent
        controller.printInfo = info
        controller.printingItem = pdfURL

        let completion: UIPrintInteractionController.CompletionHandler = { [weak self] _, _, _ in
            self?.onFinish()
        }
        if traitCollection.userInterfaceIdiom == .pad {
            controller.present(
                from: CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1),
                in: view,
                animated: true,
                completionHandler: completion
            )
        } else {
            controller.present(animated: true, completionHandler: completion)
        }
    }
}
