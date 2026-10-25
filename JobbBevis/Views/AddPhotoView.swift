import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    let job: JobRecord

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var category = PhotoCategory.during
    @State private var caption = ""
    @State private var isImporting = false
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var showCameraDenied = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo details") {
                    Picker("Category", selection: $category) {
                        ForEach(PhotoCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    TextField("Caption", text: $caption, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Add photos") {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                    }

                    Button("Take photo", systemImage: "camera", action: requestCamera)
                }

                if isImporting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Importing photos…")
                        }
                    }
                }
            }
            .navigationTitle("Add photos")
            .disabled(isImporting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: importSelectedItems)
                        .disabled(selectedItems.isEmpty || isImporting)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(
                    onCapture: { image in
                        showCamera = false
                        importCapturedImage(image)
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
                .ignoresSafeArea()
            }
            .alert("Camera unavailable", isPresented: $showCameraUnavailable) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The camera is not available on this device.")
            }
            .alert("Camera access is off", isPresented: $showCameraDenied) {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Allow camera access in Settings to take photos.")
            }
            .alert("Could not add photos", isPresented: errorBinding) {
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

    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailable = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showCamera = true
                } else {
                    showCameraDenied = true
                }
            }
        case .denied, .restricted:
            showCameraDenied = true
        @unknown default:
            showCameraDenied = true
        }
    }

    private func importSelectedItems() {
        let items = selectedItems
        Task {
            isImporting = true
            defer { isImporting = false }
            do {
                var dataItems: [Data] = []
                for item in items {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoFileError.unreadableImage
                    }
                    dataItems.append(data)
                }
                try await save(dataItems)
                dismiss()
            } catch {
                errorMessage = String(localized: "The photos could not be imported. Try again.")
            }
        }
    }

    private func importCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 1) else {
            errorMessage = String(localized: "The image could not be processed.")
            return
        }
        Task {
            isImporting = true
            defer { isImporting = false }
            do {
                try await save([data])
                dismiss()
            } catch {
                errorMessage = String(localized: "The photo could not be saved. Try again.")
            }
        }
    }

    private func save(_ dataItems: [Data]) async throws {
        var createdPhotos: [JobPhoto] = []
        var createdPaths: [String] = []
        do {
            var nextOrder = (job.photos.map(\.sortOrder).max() ?? -1) + 1
            for data in dataItems {
                let path = try await PhotoFileStore().importImageData(data, jobID: job.id)
                createdPaths.append(path)
                let photo = JobPhoto(
                    relativePath: path,
                    category: category,
                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                    sortOrder: nextOrder,
                    job: job
                )
                nextOrder += 1
                modelContext.insert(photo)
                job.photos.append(photo)
                createdPhotos.append(photo)
            }
            job.updatedAt = .now
            try modelContext.save()
        } catch {
            for photo in createdPhotos {
                modelContext.delete(photo)
            }
            for path in createdPaths {
                try? PhotoFileStore().remove(relativePath: path)
            }
            modelContext.rollback()
            throw error
        }
    }
}
