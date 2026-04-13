import Foundation

// MARK: - App Language

@Observable class AppLanguage {
    var code: String

    init() {
        code = UserDefaults.standard.string(forKey: "appLanguage") ?? "ru"
    }

    func set(_ newCode: String) {
        code = newCode
        UserDefaults.standard.set(newCode, forKey: "appLanguage")
    }

    /// Returns Russian string when language is "ru", otherwise English.
    func t(_ en: String, _ ru: String) -> String {
        code == "ru" ? ru : en
    }
}
