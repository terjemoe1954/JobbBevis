import PhotosUI
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [CompanyProfile]
    @Query(filter: #Predicate<JobRecord> { $0.sampleDataMarker == true }) private var sampleJobs: [JobRecord]
    @AppStorage(PreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(PreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var isUpdatingSamples = false
    @State private var showsRemoveSamplesConfirmation = false

    private var profile: CompanyProfile? {
        profiles.first
    }

    var body: some View {
        Form {
            CompanyProfileSection(
                profile: profile,
                selectedPhoto: $selectedPhoto,
                save: saveProfile,
                removeLogo: removeLogo
            )

            Section("App") {
                Picker("Language", selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }

                Picker("Appearance", selection: $appearanceRawValue) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
            }

            BackupSectionView()

            Section("Sample data") {
                if sampleJobs.isEmpty {
                    Button {
                        loadSampleData()
                    } label: {
                        Label("Load sample jobs", systemImage: "sparkles")
                    }
                    .disabled(isUpdatingSamples)
                } else {
                    LabeledContent("Sample jobs", value: sampleJobs.count.formatted())
                    Button("Remove sample data", role: .destructive) {
                        showsRemoveSamplesConfirmation = true
                    }
                    .disabled(isUpdatingSamples)
                }

                Text("Adds three clearly fictional jobs with illustrations. Repeated loading does not create duplicates, and removal does not affect your own records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Help") {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("How to use JobbBevis", systemImage: "questionmark.circle")
                }
            }

            Section("About") {
                LabeledContent("Version", value: versionText)
            }
        }
        .navigationTitle("Settings")
        .task {
            createProfileIfNeeded()
        }
        .task(id: selectedPhoto) {
            await importSelectedLogo()
        }
        .alert("Could not save changes", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Remove sample data?",
            isPresented: $showsRemoveSamplesConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove sample data", role: .destructive, action: removeSampleData)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only fictional sample customers, jobs, entries, and images will be removed.")
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func createProfileIfNeeded() {
        guard profiles.isEmpty else { return }
        modelContext.insert(CompanyProfile())
        saveContext()
    }

    private func saveProfile() {
        profile?.updatedAt = .now
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = String(localized: "The information could not be saved. \(error.localizedDescription)")
        }
    }

    private func importSelectedLogo() async {
        guard let selectedPhoto, let profile else { return }
        let oldRelativePath = profile.logoRelativePath
        var newRelativePath: String?
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                throw LogoImportError.noData
            }
            newRelativePath = try ManagedFileStore().saveLogo(
                data,
                replacing: nil
            )
            profile.logoRelativePath = newRelativePath
            profile.updatedAt = .now
            try modelContext.save()
            if let oldRelativePath {
                try? ManagedFileStore().removeFile(relativePath: oldRelativePath)
            }
        } catch {
            profile.logoRelativePath = oldRelativePath
            if let newRelativePath {
                try? ManagedFileStore().removeFile(relativePath: newRelativePath)
            }
            errorMessage = String(localized: "The logo could not be saved. \(error.localizedDescription)")
        }
        self.selectedPhoto = nil
    }

    private func removeLogo() {
        guard let profile, let path = profile.logoRelativePath else { return }
        do {
            profile.logoRelativePath = nil
            profile.updatedAt = .now
            try modelContext.save()
            try ManagedFileStore().removeFile(relativePath: path)
        } catch {
            profile.logoRelativePath = path
            errorMessage = String(localized: "The logo could not be removed. \(error.localizedDescription)")
        }
    }

    private func loadSampleData() {
        isUpdatingSamples = true
        Task {
            defer { isUpdatingSamples = false }
            do {
                try await SampleDataService().load(in: modelContext)
            } catch {
                errorMessage = String(localized: "Sample data could not be loaded. \(error.localizedDescription)")
            }
        }
    }

    private func removeSampleData() {
        isUpdatingSamples = true
        defer { isUpdatingSamples = false }
        do {
            try SampleDataService().remove(in: modelContext)
        } catch {
            errorMessage = String(localized: "Sample data could not be removed. \(error.localizedDescription)")
        }
    }
}

private struct CompanyProfileSection: View {
    let profile: CompanyProfile?
    @Binding var selectedPhoto: PhotosPickerItem?
    let save: () -> Void
    let removeLogo: () -> Void

    var body: some View {
        Section("Company profile") {
            if let profile {
                LogoView(relativePath: profile.logoRelativePath)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        profile.logoRelativePath == nil ? "Choose logo" : "Change logo",
                        systemImage: "photo"
                    )
                }

                if profile.logoRelativePath != nil {
                    Button("Remove logo", role: .destructive, action: removeLogo)
                }

                TextField("Company name", text: Bindable(profile).name)
                    .onSubmit(save)
                TextField("Organization number", text: Bindable(profile).organizationNumber)
                    .keyboardType(.numbersAndPunctuation)
                    .onSubmit(save)
                TextField("Phone", text: Bindable(profile).phone)
                    .keyboardType(.phonePad)
                    .onSubmit(save)
                TextField("Email", text: Bindable(profile).email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .onSubmit(save)
                TextField("Address", text: Bindable(profile).address, axis: .vertical)
                    .lineLimit(2...4)
                    .onSubmit(save)

                Button("Save company profile", action: save)
            } else {
                ProgressView()
            }
        }
    }
}

private struct LogoView: View {
    let relativePath: String?

    var body: some View {
        if let data = ManagedFileStore().data(relativePath: relativePath),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 120)
                .accessibilityLabel("Company logo")
        }
    }
}

private enum LogoImportError: LocalizedError {
    case noData

    var errorDescription: String? {
        String(localized: "The selected image could not be read.")
    }
}
