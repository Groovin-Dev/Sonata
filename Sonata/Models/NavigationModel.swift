//
//  NavigationModel.swift
//  Sonata
//

import SwiftUI
import Combine

enum SonataSection: String, CaseIterable, Identifiable {
    case discover
    case trending
    case favorites
    case queue
    case playlists
    case history
    case downloads
    case hypemFeed
    case hypemBlogs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .discover: return "Discover"
        case .trending: return "Trending"
        case .favorites: return "Favorites"
        case .queue: return "Queue"
        case .playlists: return "Playlists"
        case .history: return "History"
        case .downloads: return "Downloads"
        case .hypemFeed: return "Feed"
        case .hypemBlogs: return "Blogs"
        }
    }

    var groupTitle: String {
        switch self {
        case .discover, .trending, .favorites, .queue:
            return "Sonata"
        case .playlists, .history, .downloads:
            return "Your Library"
        case .hypemFeed, .hypemBlogs:
            return "HypeM"
        }
    }
}

final class NavigationModel: ObservableObject {
    @Published var selectedSection: SonataSection = .discover
}
