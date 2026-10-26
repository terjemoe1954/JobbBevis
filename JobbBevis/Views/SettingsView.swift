import PhotosUI
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [CompanyProfile]
    @AppStorage(PreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(PreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

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

            Section("Catalog") {
                NavigationLink {
                    ProductCatalogView()
                } label: {
                    Label("Product catalog", systemImage: "shippingbox.fill")
                }
            }

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

}

private struct CompanyProfileSection: View {
    @Environment(\.locale) private var locale
    let profile: CompanyProfile?
    @Binding var selectedPhoto: PhotosPickerItem?
    let save: () -> Void
    let removeLogo: () -> Void
    @State private var hourlyRateText = ""
    @State private var drivingRateText = ""
    @State private var rateError = false
    @State private var organizationNumber = ""
    @State private var bankAccount = ""
    @State private var showsOrganizationNumberError = false
    @State private var showsBankAccountError = false

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
                TextField("Organization number", text: $organizationNumber)
                    .keyboardType(.numbersAndPunctuation)
                if showsOrganizationNumberError {
                    Text("Enter a valid Norwegian organization number with 9 digits.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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

                TextField("Bank account", text: $bankAccount)
                    .keyboardType(.numbersAndPunctuation)
                if showsBankAccountError {
                    Text("Enter a valid Norwegian bank account number with 11 digits.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Toggle("Registered in the VAT Register", isOn: Binding(
                    get: { profile.isVATRegistered },
                    set: { profile.isVATRegistered = $0; save() }
                ))
                Toggle("Registered in the Register of Business Enterprises", isOn: Binding(
                    get: { profile.isRegisteredInBusinessRegister },
                    set: { profile.isRegisteredInBusinessRegister = $0; save() }
                ))

                Text("Default rates")
                    .font(.headline)
                TextField("Default hourly rate, excluding VAT", text: $hourlyRateText)
                    .keyboardType(.decimalPad)
                TextField("Default price per km, excluding VAT", text: $drivingRateText)
                    .keyboardType(.decimalPad)
                if rateError {
                    Text("Enter valid non-negative rates using the local decimal separator.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Save default rates") {
                    saveRates(to: profile)
                }

                Button("Save company profile") {
                    saveCompanyProfile(profile)
                }
            } else {
                ProgressView()
            }
        }
        .task(id: profile?.id) {
            guard let profile else { return }
            hourlyRateText = profile.defaultHourlyRate.map {
                EntryFormatting.formatDecimal($0, locale: locale)
            } ?? ""
            drivingRateText = profile.defaultDrivingRatePerKilometer.map {
                EntryFormatting.formatDecimal($0, locale: locale)
            } ?? ""
            organizationNumber = profile.organizationNumber
            bankAccount = profile.bankAccount ?? ""
        }
    }

    private func saveRates(to profile: CompanyProfile) {
        let hourly = parseOptionalRate(hourlyRateText)
        let driving = parseOptionalRate(drivingRateText)
        let hourlyValid = hourlyRateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hourly != nil
        let drivingValid = drivingRateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || driving != nil
        rateError = !hourlyValid || !drivingValid
        guard !rateError else { return }
        profile.defaultHourlyRate = hourly
        profile.defaultDrivingRatePerKilometer = driving
        save()
    }

    private func saveCompanyProfile(_ profile: CompanyProfile) {
        let trimmedOrganizationNumber = organizationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBankAccount = bankAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        let validOrganizationNumber = NorwegianNumberValidator.organizationNumberDigits(
            from: trimmedOrganizationNumber
        )
        let validBankAccount = trimmedBankAccount.isEmpty
            ? nil
            : NorwegianNumberValidator.bankAccountDigits(from: trimmedBankAccount)

        showsOrganizationNumberError = validOrganizationNumber == nil
        showsBankAccountError = !trimmedBankAccount.isEmpty && validBankAccount == nil
        guard let validOrganizationNumber, !showsBankAccountError else { return }

        profile.organizationNumber = validOrganizationNumber
        if let validBankAccount {
            profile.bankAccount = NorwegianNumberValidator.formattedBankAccount(validBankAccount)
        } else {
            profile.bankAccount = nil
        }
        organizationNumber = validOrganizationNumber
        bankAccount = profile.bankAccount ?? ""
        save()
    }

    private func parseOptionalRate(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let value = EntryFormatting.parseDecimal(trimmed, locale: locale),
              value >= 0 else { return nil }
        return value
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
