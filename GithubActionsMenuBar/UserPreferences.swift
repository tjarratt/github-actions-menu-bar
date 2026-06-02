import Foundation
import Security

/// Stores the user's GitHub token (in the Keychain), repository owner, and
/// repository name (in UserDefaults).
final class UserPreferences {
    static let shared = UserPreferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let repoOwner              = "repoOwner"
        static let repoName               = "repoName"
        static let acknowledgedWorkflowIDs = "acknowledgedWorkflowIDs"
    }

    private let keychainService = "com.github-actions-menu-bar"
    private let keychainAccount = "github-token"

    // MARK: - Properties

    var repoOwner: String {
        get { defaults.string(forKey: Keys.repoOwner) ?? "" }
        set { defaults.set(newValue, forKey: Keys.repoOwner) }
    }

    var repoName: String {
        get { defaults.string(forKey: Keys.repoName) ?? "" }
        set { defaults.set(newValue, forKey: Keys.repoName) }
    }

    /// GitHub Personal Access Token – stored securely in the Keychain.
    var githubToken: String {
        get { loadTokenFromKeychain() ?? "" }
        set { saveTokenToKeychain(newValue) }
    }

    /// Workflow IDs the user has acknowledged as persistently failing.
    var acknowledgedWorkflowIDs: Set<Int> {
        get {
            let array = defaults.array(forKey: Keys.acknowledgedWorkflowIDs) as? [Int] ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.acknowledgedWorkflowIDs)
        }
    }

    /// Returns `true` when all three configuration values are non-empty.
    var isConfigured: Bool {
        !repoOwner.isEmpty && !repoName.isEmpty && !githubToken.isEmpty
    }

    // MARK: - Keychain helpers

    private func saveTokenToKeychain(_ token: String) {
        guard let tokenData = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        // Attempt an update first; if the item doesn't exist, add it.
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: tokenData] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = tokenData
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
