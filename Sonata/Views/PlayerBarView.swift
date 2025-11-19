//
//  PlayerBarView.swift
//  Sonata
//

import SwiftUI
import Combine

struct PlayerBarView: View {
    @EnvironmentObject private var playbackModel: PlaybackModel
    @EnvironmentObject private var hypeMService: MockHypeMService

    @State private var isScrubbing = false
    @State private var sliderValue: Double = 0
    @State private var isProgressHovered = false
    @State private var showVolumeSlider = false

    var body: some View {
        HStack(spacing: 16) {
            // Transport controls
            HStack(spacing: 8) {
                Button { playbackModel.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(playbackModel.isShuffled ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)

                Button { playbackModel.playPrevious() } label: {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.plain)

                Button { playbackModel.togglePlayPause() } label: {
                    Image(systemName: playbackModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(playbackModel.state == PlaybackState.buffering)

                Button { playbackModel.playNext() } label: {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.plain)

                Button { playbackModel.toggleRepeat() } label: {
                    Image(systemName: playbackModel.repeatMode == .one ? "repeat.1" : "repeat")
                        .foregroundStyle(playbackModel.repeatMode != .off ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            .font(.body)

            // Song info + favorite + volume
            HStack(spacing: 10) {
                ArtworkView(track: playbackModel.currentTrack, cornerRadius: 6)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playbackModel.currentTrack?.title ?? "Nothing Playing")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Text(artistAlbumText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Button {
                    if let currentTrack = playbackModel.currentTrack {
                        let updated = hypeMService.toggleFavorite(for: currentTrack)
                        playbackModel.updateFavorite(with: updated)
                    }
                } label: {
                    Image(systemName: playbackModel.currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                        .foregroundStyle(playbackModel.currentTrack?.isFavorite == true ? .red : .secondary)
                }
                .buttonStyle(.plain)

                // Volume toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showVolumeSlider.toggle()
                    }
                } label: {
                    Image(systemName: volumeIcon)
                        .foregroundStyle(showVolumeSlider ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .leading) {
                    if showVolumeSlider {
                        HStack(spacing: 6) {
                            Slider(value: $playbackModel.volume, in: 0...1)
                                .tint(.accentColor)
                                .frame(width: 70)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .capsule)
                        .offset(x: -86)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .overlay(alignment: .bottom) {
            progressBar
        }
        .onChange(of: playbackModel.currentTime) { _, _ in
            if !isScrubbing && playbackModel.duration > 0 {
                sliderValue = playbackModel.currentTime / playbackModel.duration
            }
        }
        .onChange(of: playbackModel.duration) { _, _ in
            if !isScrubbing && playbackModel.duration > 0 {
                sliderValue = playbackModel.currentTime / playbackModel.duration
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var progressBar: some View {
        VStack(spacing: 0) {
            // Invisible hit area above the bar
            Color.clear
                .frame(height: 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))

                    // Progress fill
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: max(0, geo.size.width * CGFloat(sliderValue)))

                    // Seek handle when hovered/scrubbing
                    if isProgressHovered || isScrubbing {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                            .position(x: geo.size.width * CGFloat(sliderValue), y: geo.size.height / 2)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            sliderValue = fraction
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            sliderValue = fraction
                            playbackModel.seek(toFraction: sliderValue)
                            isScrubbing = false
                        }
                )
            }
            .frame(height: isProgressHovered || isScrubbing ? 10 : 3)
            .clipShape(.rect(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isProgressHovered = hovering
            }
        }
    }

    // MARK: - Computed Properties

    private var artistAlbumText: String {
        guard let track = playbackModel.currentTrack else { return "" }
        // If we have album info, show "Artist - Album", otherwise just artist
        return track.artist
    }

    private var volumeIcon: String {
        if playbackModel.volume == 0 {
            return "speaker.slash.fill"
        } else if playbackModel.volume < 0.33 {
            return "speaker.fill"
        } else if playbackModel.volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    // MARK: - Helpers

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite && !t.isNaN else { return "--:--" }
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    PlayerBarView()
        .environmentObject(PlaybackModel())
        .environmentObject(MockHypeMService())
        .padding()
        .frame(width: 600)
}
