import Foundation

enum Settings {
    static let modelKey = "claudeModel"
    static let localeKey = "speechLocale"            // "" = device language
    static let silenceGapKey = "silenceGapSeconds"   // pause that ends a conversation
    static let minWordsKey = "minWordsPerConversation"
    static let userNameKey = "userName"

    static var silenceGap: TimeInterval {
        let v = UserDefaults.standard.double(forKey: silenceGapKey)
        return v > 0 ? v : 120
    }
    static var minWords: Int {
        let v = UserDefaults.standard.integer(forKey: minWordsKey)
        return v > 0 ? v : 12
    }
    static var userName: String { UserDefaults.standard.string(forKey: userNameKey) ?? "" }
    static var speechLocale: Locale {
        let id = UserDefaults.standard.string(forKey: localeKey) ?? ""
        return id.isEmpty ? .current : Locale(identifier: id)
    }

    static let speechLocales: [(id: String, label: String)] = [
        ("", "Device language"),
        ("en-US", "English (US)"),
        ("es-MX", "Español (México)"),
        ("es-ES", "Español (España)"),
        ("es-US", "Español (EE. UU.)"),
    ]
}
