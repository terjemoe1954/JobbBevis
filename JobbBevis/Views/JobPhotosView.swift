import SwiftData
import SwiftUI

struct JobPhotosView: View {
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    @State private var isAddingPhoto = false
    @State private var errorMessage: String?

    private var orderedPhotos: [JobPhoto] {
        job.photos.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Group {
            if orderedPhotos.isEmpty {
                PhotoEmptyState(addPhoto: { isAddingPhoto = true })
            } else {
                List {
                    ForEach(orderedPhotos) { photo in
                        NavigationLink {
                            PhotoDetailView(photo: photo)
                        } label: {
                            PhotoRowView(photo: photo)
                        }
                    }
                    .onMove(perform: movePhotos)
                }
            }
        }
        .navigationTitle("Photos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add photos", systemImage: "plus") {
                    isAddingPhoto = true
                }
            }
            if !orderedPhotos.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $isAddingPhoto) {
            AddPhotoView(job: job)
        }
        .alert("Could not save changes", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func movePhotos(from offsets: IndexSet, to destination: Int) {
        var reordered = orderedPhotos
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, photo) in reordered.enumerated() {
            photo.sortOrder = index
        }
        job.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The photo order could not be saved. \(error.localizedDescription)")
        }
    }
}

private struct PhotoEmptyState: View {
    let addPhoto: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No photos", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Add before, during, or after photos to document the work.")
        } actions: {
            Button("Add photos", systemImage: "plus", action: addPhoto)
        }
    }
}

private struct PhotoRowView: View {
    let photo: JobPhoto

    var body: some View {
        HStack(spacing: 12) {
            AsyncManagedImageView(relativePath: photo.relativePath, maximumPixelSize: 240)
                .frame(width: 88, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(photo.category.title)
                    .font(.headline)
                if !photo.caption.isEmpty {
                    Text(photo.caption)
                        .lineLimit(2)
                }
                Text("Registered \(photo.registeredAt, format: .dateTime.day().month().year().hour().minute())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
