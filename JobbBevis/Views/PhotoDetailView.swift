import SwiftData
import SwiftUI

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let photo: JobPhoto
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncManagedImageView(relativePath: photo.relativePath, maximumPixelSize: 1_600)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                PhotoMetadataView(
                    category: photo.category,
                    caption: photo.caption,
                    registeredAt: photo.registeredAt
                )
            }
            .padding()
        }
        .navigationTitle(photo.category.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") {
                    isEditing = true
                }
                Button("Delete photo", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            PhotoEditView(photo: photo)
        }
        .confirmationDialog(
            "Delete photo?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deletePhoto)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The photo will be removed from this job and deleted from app storage.")
        }
        .alert("Could not delete photo", isPresented: errorBinding) {
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

    private func deletePhoto() {
        do {
            let stagedRemoval = try PhotoFileStore().stageRemoval(relativePath: photo.relativePath)
            let job = photo.job
            modelContext.delete(photo)
            job.updatedAt = .now
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                try? stagedRemoval.restore()
                throw error
            }
            try stagedRemoval.commit()
            dismiss()
        } catch {
            errorMessage = String(localized: "The photo could not be deleted. \(error.localizedDescription)")
        }
    }
}

private struct PhotoMetadataView: View {
    let category: PhotoCategory
    let caption: String
    let registeredAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(category.title)
            } icon: {
                Image(systemName: "tag")
            }
            Label {
                Text("Registered \(registeredAt, format: .dateTime.day().month().year().hour().minute())")
            } icon: {
                Image(systemName: "calendar")
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.body)
            }
        }
    }
}

private struct PhotoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let photo: JobPhoto
    @State private var category: PhotoCategory
    @State private var caption: String
    @State private var errorMessage: String?

    init(photo: JobPhoto) {
        self.photo = photo
        _category = State(initialValue: photo.category)
        _caption = State(initialValue: photo.caption)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(PhotoCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                TextField("Caption", text: $caption, axis: .vertical)
                    .lineLimit(2...5)
            }
            .navigationTitle("Edit photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .alert("Could not save changes", isPresented: errorBinding) {
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

    private func save() {
        photo.category = category
        photo.caption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        photo.job.updatedAt = .now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "The photo could not be saved. \(error.localizedDescription)")
        }
    }
}
