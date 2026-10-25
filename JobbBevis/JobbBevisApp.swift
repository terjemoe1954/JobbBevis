import SwiftData
import SwiftUI

@main
struct JobbBevisApp: App {
    private let persistenceResult: Result<ModelContainer, Error>

    init() {
        persistenceResult = Result {
            try PersistenceService.makeContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            switch persistenceResult {
            case .success(let container):
                AppRootView()
                    .modelContainer(container)
            case .failure(let error):
                StorageFailureView(error: error)
            }
        }
    }
}

private struct StorageFailureView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Data could not be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("JobbBevis did not change or reset your stored data. Close the app and try again. If the problem continues, contact support.\n\n\(error.localizedDescription)")
        }
    }
}
