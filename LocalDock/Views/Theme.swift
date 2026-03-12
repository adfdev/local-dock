import SwiftUI

enum Theme {
    // Coder palette - vibrant but clean
    static let accent = Color(hex: "#4195FB")       // Electric blue
    static let mint = Color(hex: "#50E3C2")          // Mint/teal
    static let coral = Color(hex: "#FF6B6B")         // Soft red
    static let amber = Color(hex: "#FFB86C")         // Warm amber
    static let violet = Color(hex: "#BD93F9")        // Soft purple
    static let emerald = Color(hex: "#50FA7B")       // Green
    static let pink = Color(hex: "#FF79C6")          // Pink
    static let cyan = Color(hex: "#8BE9FD")          // Cyan
    static let comment = Color(hex: "#6272A4")       // Muted blue-gray

    // Surfaces
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceHover = Color.primary.opacity(0.04)
    static let border = Color.primary.opacity(0.08)

    // Port colors by range
    static func portColor(for port: Int) -> Color {
        switch port {
        case 3000..<4000: return accent       // React, Next.js etc
        case 4000..<5000: return violet       // Vite, custom
        case 5000..<6000: return emerald      // Flask, misc
        case 5173: return violet              // Vite
        case 5432: return cyan                // PostgreSQL
        case 6379: return coral               // Redis
        case 8000..<9000: return amber        // Django, Spring
        case 27017: return emerald            // MongoDB
        default: return comment
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
