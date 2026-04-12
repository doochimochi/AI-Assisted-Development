import Foundation
import Security

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var anthropicApiKey: String = ""
    @Published var deepgramApiKey: String = ""
    @Published var overlayOpacity: Double = 0.92
    @Published var overlayWidth: CGFloat = 380
    @Published var useCloudSTT: Bool = true  // false = WhisperKit (offline, high RAM)
    @Published var autoSaveSession: Bool = true
    @Published var maxTranscriptMinutes: Int = 10

    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    func load() {
        overlayOpacity = defaults.double(forKey: "overlayOpacity").nonZeroOr(0.92)
        overlayWidth = CGFloat(defaults.double(forKey: "overlayWidth").nonZeroOr(380))
        useCloudSTT = defaults.object(forKey: "useCloudSTT") as? Bool ?? true
        autoSaveSession = defaults.object(forKey: "autoSaveSession") as? Bool ?? true
        maxTranscriptMinutes = defaults.integer(forKey: "maxTranscriptMinutes").nonZeroOr(10)
        anthropicApiKey = readFromKeychain(service: "MeetingAssistant", account: "anthropicApiKey")
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        deepgramApiKey = readFromKeychain(service: "MeetingAssistant", account: "deepgramApiKey")
            ?? ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] ?? ""
    }

    func save() {
        defaults.set(overlayOpacity, forKey: "overlayOpacity")
        defaults.set(Double(overlayWidth), forKey: "overlayWidth")
        defaults.set(useCloudSTT, forKey: "useCloudSTT")
        defaults.set(autoSaveSession, forKey: "autoSaveSession")
        defaults.set(maxTranscriptMinutes, forKey: "maxTranscriptMinutes")
        if !anthropicApiKey.isEmpty {
            saveToKeychain(service: "MeetingAssistant", account: "anthropicApiKey", value: anthropicApiKey)
        }
        if !deepgramApiKey.isEmpty {
            saveToKeychain(service: "MeetingAssistant", account: "deepgramApiKey", value: deepgramApiKey)
        }
    }

    var isConfigured: Bool {
        !anthropicApiKey.isEmpty && !deepgramApiKey.isEmpty
    }

    // MARK: - Keychain

    private func saveToKeychain(service: String, account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func readFromKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double { self == 0 ? fallback : self }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
