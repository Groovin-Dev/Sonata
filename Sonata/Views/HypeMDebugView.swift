//
//  HypeMDebugView.swift
//  Sonata
//

import SwiftUI
import AppKit

struct HypeMDebugView: View {
    @EnvironmentObject private var hypeMService: MockHypeMService

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var deviceId: String = ""
    @State private var isLoading = false
    @State private var token: String?
    @State private var saveToken = true
    @State private var saveCredentials = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HypeM Debug Console")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                TextField("Device ID (hex, optional)", text: $deviceId)
                    .textFieldStyle(.roundedBorder)
                Toggle("Save hm_token in UserDefaults", isOn: $saveToken)
                Toggle("Save credentials in Keychain", isOn: $saveCredentials)

                HStack {
                    Button("Login") { Task { await login() } }
                        .disabled(isLoading || username.isEmpty || password.isEmpty)
                    Button("Fetch What's New") { Task { await fetchWhatsNew() } }
                        .disabled(isLoading)
                }
                if let token {
                    Text("hm_token: \(token)")
                        .font(.callout)
                        .foregroundColor(.accentColor)
                        .textSelection(.enabled)
                    Text("Request body is form-encoded; spaces become +.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
        .background(.regularMaterial)
        .onAppear {
            prefillCredentials()
        }
    }

    @MainActor
    private func login() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await hypeMService.loginDebug(username: username, password: password, deviceIdOverride: deviceId.nonEmpty)
            let token = result.token
            self.token = token
            hypeMService.setAuthToken(token)
            if saveToken {
                hypeMService.setAuthToken(token)
            }
            if saveCredentials {
                hypeMService.saveCredentials(username: username, password: password)
            } else {
                hypeMService.clearCredentials()
            }
            appendLog("Login succeeded. hm_token=\(token) status=\(result.status) url=\(result.url) saved_token=\(saveToken) saved_credentials=\(saveCredentials)")
            appendLog("Raw response: \(result.raw)")
        } catch let apiError as HypeMError {
            appendLog("Login failed. status=\(apiError.status) body=\(apiError.body)")
        } catch let urlError as URLError {
            let nsError = urlError as NSError
            appendLog("Login failed. code=\(urlError.errorCode) domain=\(nsError.domain) description=\(urlError.localizedDescription)")
        } catch {
            appendLog("Login failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func fetchWhatsNew() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await hypeMService.refreshFromWhatsNewDebug()
            appendLog("Fetched \(result.tracks.count) tracks from what's new. status=\(result.status) url=\(result.url)")
            appendLog("Raw response: \(result.raw.prefix(800))")
            if let first = result.tracks.first {
                appendLog("First track: \(first.title) – \(first.artist)")
            }
        } catch let apiError as HypeMError {
            appendLog("Fetch failed. status=\(apiError.status) body=\(apiError.body)")
        } catch {
            appendLog("Fetch failed: \(error.localizedDescription)")
        }
    }

    private func appendLog(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(line)"
        print(entry)
    }

    private func prefillCredentials() {
        if let creds = hypeMService.loadSavedCredentials() {
            username = creds.username
            password = creds.password
            saveCredentials = true
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
