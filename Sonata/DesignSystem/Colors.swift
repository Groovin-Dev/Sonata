//
//  Colors.swift
//  Sonata
//

import SwiftUI

enum SonataColor {
    // Core neutrals
    static let pianoBlack = Color(hex: "#050509")
    static let softCharcoal = Color(hex: "#15151A")
    static let graphiteGlass = Color.black.opacity(0.45)
    static let ivory = Color(hex: "#FAF7F1")
    static let softStone = Color(hex: "#F4F4F7") // optional light mode background

    // Accents
    static let amberGlow = Color(hex: "#F5B35C")
    static let burgundyVelvet = Color(hex: "#6F2030")
    static let forestInk = Color(hex: "#193427")
}

// Hex helper lives alongside tokens so it can be shared across views.
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
