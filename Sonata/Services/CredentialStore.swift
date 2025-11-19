//
//  CredentialStore.swift
//  Sonata
//

import Foundation
import Security

protocol CredentialStoring {
    func save(username: String, password: String) throws
    func load() throws -> (username: String, password: String)?
    func clear() throws
}

final class KeychainCredentialStore: CredentialStoring {
    private let service = "Sonata.HypeM"
    private let account = "hypem_user"

    func save(username: String, password: String) throws {
        try clear()
        let passwordData = Data(password.utf8)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: "HypeM Credentials",
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecAttrGeneric as String: Data(username.utf8)
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func load() throws -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let result = item as? [String: Any] else {
            throw KeychainError(status: status)
        }
        guard
            let passwordData = result[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: .utf8)
        else {
            throw KeychainError(status: errSecDecode)
        }
        let usernameData = result[kSecAttrGeneric as String] as? Data
        let username = usernameData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return (username: username, password: password)
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Keychain error \(status)"
    }
}
