import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case norwegian = "nb"
    case english = "en"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .system: "System language"
        case .norwegian: "Norwegian Bokmål"
        case .english: "English"
        }
    }

    var locale: Locale? {
        self == .system ? nil : Locale(identifier: rawValue)
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .system: "System appearance"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum PreferenceKey {
    static let language = "selectedLanguage"
    static let appearance = "selectedAppearance"
    static let validatesNorwegianNumbers = "validatesNorwegianNumbers"
}

enum NumberValidationPreference {
    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: PreferenceKey.validatesNorwegianNumbers) != nil else {
            return true
        }
        return defaults.bool(forKey: PreferenceKey.validatesNorwegianNumbers)
    }
}
