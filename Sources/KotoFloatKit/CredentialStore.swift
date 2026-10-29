import Foundation
import LocalAuthentication
import Security

@MainActor protocol CredentialStore {
    func token(for endpoint: String) throws -> String?
    func setToken(_ token: String?, for endpoint: String) throws
}

@MainActor struct KeychainCredentialStore: CredentialStore {
    private func query(_ endpoint: String) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        return [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.tasuku24.KotoFloat.translation",
         kSecAttrAccount as String: endpoint,
         kSecUseAuthenticationContext as String: context]
    }

    func token(for endpoint: String) throws -> String? {
        var request = query(endpoint)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { throw TranslationFailure.credentialsUnavailable }
        return token
    }

    func setToken(_ token: String?, for endpoint: String) throws {
        let request = query(endpoint)
        guard let token, !token.isEmpty else {
            let status = SecItemDelete(request as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw TranslationFailure.credentialsUnavailable }
            return
        }
        let data = Data(token.utf8)
        var status = SecItemUpdate(request as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = request
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw TranslationFailure.credentialsUnavailable }
    }
}
