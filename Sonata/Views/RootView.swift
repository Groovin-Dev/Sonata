//
//  RootView.swift
//  Sonata
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var navigationModel: NavigationModel
    @EnvironmentObject private var playbackModel: PlaybackModel
    @EnvironmentObject private var hypeMService: MockHypeMService
    @State private var didBootstrap = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 200)
        } detail: {
            ZStack(alignment: .bottom) {
                ContentView()
                    .frame(minWidth: 400, minHeight: 300)

                PlayerBarView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            await hypeMService.bootstrapAndMaybeRefresh(playbackModel: playbackModel)
        }
    }
}
