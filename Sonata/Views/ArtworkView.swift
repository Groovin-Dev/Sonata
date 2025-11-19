//
//  ArtworkView.swift
//  Sonata
//

import SwiftUI

struct ArtworkView: View {
    let track: Track?
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let url = track?.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else if let artworkName = track?.artworkName, !artworkName.isEmpty {
                Image(artworkName)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(gradientForTrack(track))
            .overlay {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
            }
    }

    private func gradientForTrack(_ track: Track?) -> LinearGradient {
        let base = (track?.title ?? "Sonata") + (track?.artist ?? "")
        let hash = abs(base.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash >> 8) % 360) / 360.0

        let color1 = Color(hue: hue1, saturation: 0.55, brightness: 0.9)
        let color2 = Color(hue: hue2, saturation: 0.65, brightness: 0.75)

        return LinearGradient(
            colors: [
                color1,
                color2,
                Color.black.opacity(0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
