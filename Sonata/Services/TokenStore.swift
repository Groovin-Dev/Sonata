//
//  TokenStore.swift
//  Sonata
//

import Foundation

protocol TokenStoring {
    func saveToken(_ token: String?)
    func loadToken() -> String?
    func clear() -> Void
}

final class TokenStore: TokenStoring {
    private let key = "hypem_hm_token"

    func saveToken(_ token: String?) {
        let defaults = UserDefaults.standard
        if let token {
            defaults.set(token, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func loadToken() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
