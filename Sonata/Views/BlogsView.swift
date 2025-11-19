//
//  BlogsView.swift
//  Sonata
//

import SwiftUI

struct BlogsView: View {
    @EnvironmentObject private var hypeMService: MockHypeMService
    @EnvironmentObject private var playbackModel: PlaybackModel
    @State private var isLoading = false
    @State private var selectedTracks: [Track] = []
    @State private var selectedBlogName: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Blogs")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                if isLoading { ProgressView().tint(.accentColor) }
            }
            .padding(.horizontal)

            if hypeMService.blogsStore.isEmpty && !isLoading {
                Text("No blogs loaded.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(hypeMService.blogsStore) { blog in
                        Button {
                            Task { await loadTracks(for: blog) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(blog.sitename).font(.headline)
                                    if let region = blog.region_name {
                                        Text(region).font(.subheadline).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if let count = blog.total_tracks {
                                    Text("\(count) tracks")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.inset)
            }

            if !selectedTracks.isEmpty {
                Divider()
                Text("Tracks from \(selectedBlogName)")
                    .font(.headline)
                    .padding(.horizontal)
                List(selectedTracks, id: \.id) { track in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(track.title).font(.headline)
                            Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            playbackModel.setQueue(selectedTracks, startAt: track)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.automatic)
                    }
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadBlogs() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
            }
        }
        .task { await loadBlogs() }
    }

    private func loadBlogs() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        _ = await hypeMService.refreshBlogsLive()
    }

    private func loadTracks(for blog: Blog) async {
        selectedBlogName = blog.sitename
        selectedTracks = await hypeMService.refreshBlogTracks(siteId: blog.siteid)
    }
}

#Preview {
    BlogsView()
        .environmentObject(MockHypeMService())
        .environmentObject(PlaybackModel())
}
