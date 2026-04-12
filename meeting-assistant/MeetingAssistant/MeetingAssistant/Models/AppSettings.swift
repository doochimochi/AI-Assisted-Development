import Foundation
import Security

/// All user-configurable settings.
/// API keys use Keychain in RELEASE and environment variables in DEBUG.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: - API Keys

    var anthropicAPIKey: String {
        get { resolveKey("ANTHROPIC_API_KEY", keychainItem: "com.meetingassistant.anthropic-key") }
        set { storeKey(newValue, keychainItem: "com.meetingassistant.anthropic-key") }
    }

    var deepgramAPIKey: String {
        get { resolveKey("DEEPGRAM_API_KEY", keychainItem: "com.meetingassistant.deepgram-key") }
        set { storeKey(newValue, keychainItem: "com.meetingassistant.deepgram-key") }
    }

    // MARK: - UI

    @Published var overlayOpacity: Double {
        didSet { UserDefaults.standard.set(overlayOpacity, forKey: "overlayOpacity") }
    }

    @Published var useOfflineSTT: Bool {
        didSet { UserDefaults.standard.set(useOfflineSTT, forKey: "useOfflineSTT") }
    }

    // MARK: - AI Feature Limits

    /// Max AI word-research calls per minute (rate limiting)
    let wordResearchCooldownSeconds: TimeInterval = 10
    /// Max answer-finder calls per minute
    let answerFinderCooldownSeconds: TimeInterval = 2
    /// How often to auto-generate question suggestions
    let questionGeneratorIntervalSeconds: TimeInterval = 30
    /// Max AI result items kept in memory per feature
    let maxResultsPerFeature: Int = 10
    /// Rolling transcript window kept in memory
    let transcriptWindowMinutes: TimeInterval = 10 * 60

    // MARK: - Init

    private init() {
        overlayOpacity = UserDefaults.standard.double(forKey: "overlayOpacity").nonZeroOr(0.85)
        useOfflineSTT  = UserDefaults.standard.bool(forKey: "useOfflineSTT")
    }

    // MARK: - Private Helpers

    private func resolveKey(_ envVar: String, keychainItem: String) -> String {
        #if DEBUG
        if let val = ProcessInfo.processInfo.environment[envVar], !val.isEmpty { return val }
        #endif
        return keychainLoad(item: keychainItem) ?? ""
    }

    private func keychainLoad(item: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: item,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private func storeKey(_ value: String, keychainItem: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainItem
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double { self == 0 ? fallback : self }
}
