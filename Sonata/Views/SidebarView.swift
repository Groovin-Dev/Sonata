//
//  SidebarView.swift
//  Sonata
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var navigationModel: NavigationModel

    private var groupedSections: [String: [SonataSection]] {
        Dictionary(grouping: SonataSection.allCases) { $0.groupTitle }
    }

    var body: some View {
        List(selection: $navigationModel.selectedSection) {
            ForEach(["Sonata", "Your Library", "HypeM"], id: \.self) { group in
                Section(group) {
                    ForEach(groupedSections[group] ?? []) { section in
                        Label(section.displayName, systemImage: section.iconName)
                            .tag(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}

private extension SonataSection {
    var iconName: String {
        switch self {
        case .discover: return "sparkles"
        case .trending: return "flame.fill"
        case .favorites: return "heart.fill"
        case .queue: return "text.line.first.and.arrowtriangle.forward"
        case .playlists: return "music.note.list"
        case .history: return "clock.arrow.circlepath"
        case .downloads: return "arrow.down.circle"
        case .hypemFeed: return "dot.radiowaves.left.and.right"
        case .hypemBlogs: return "bubble.left.and.text.bubble.right"
        }
    }
}
