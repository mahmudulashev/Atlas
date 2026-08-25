import SwiftUI

/// Observable holder so a language switch re-renders the whole interface.

@MainActor
final class Localization: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "uz.overview.language") }
    }

    var t: L10n { L10n(language: language) }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "uz.overview.language"),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .systemDefault
        }
    }
}
