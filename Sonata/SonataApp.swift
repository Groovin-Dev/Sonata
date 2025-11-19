//
//  SonataApp.swift
//  Sonata
//

import SwiftUI
import AppKit

@main
struct SonataApp: App {
    @StateObject private var navigationModel = NavigationModel()
    @StateObject private var playbackModel = PlaybackModel()
    @StateObject private var hypeMService = MockHypeMService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(navigationModel)
                .environmentObject(playbackModel)
                .environmentObject(hypeMService)
                .task {
                    await hypeMService.bootstrapAndMaybeRefresh(playbackModel: playbackModel)
                }
        }
        .windowStyle(.titleBar)

        // Developer test window for API validation.
        WindowGroup("HypeM Debug", id: "hypemDebug") {
            HypeMDebugView()
                .environmentObject(hypeMService)
        }
        .windowStyle(.titleBar)

        .commands {
            DebugCommands()
        }
    }
}

private struct DebugCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Debug") {
            Button("Open HypeM Debug") {
                openWindow(id: "hypemDebug")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
