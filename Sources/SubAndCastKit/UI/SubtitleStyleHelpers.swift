import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Color Hex Conversion

extension Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b, a: Double
        switch cleanHex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            r = 1.0; g = 1.0; b = 1.0; a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    public func toHex() -> String {
        #if canImport(AppKit)
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int((rgbColor.redComponent * 255).rounded())
        let g = Int((rgbColor.greenComponent * 255).rounded())
        let b = Int((rgbColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return "#FFFFFF"
        #endif
    }
}

// MARK: - Subtitle Font Helper

extension Font {
    public static func subtitleFont(
        family: String,
        size: CGFloat,
        isBold: Bool = true,
        isItalic: Bool = false
    ) -> Font {
        var baseFont: Font
        switch family {
        case "System Rounded":
            baseFont = .system(size: size, weight: isBold ? .bold : .regular, design: .rounded)
        case "System Serif":
            baseFont = .system(size: size, weight: isBold ? .bold : .regular, design: .serif)
        case "System Monospaced":
            baseFont = .system(size: size, weight: isBold ? .bold : .regular, design: .monospaced)
        case "System Default":
            baseFont = .system(size: size, weight: isBold ? .bold : .regular, design: .default)
        default:
            baseFont = .custom(family, size: size)
            if isBold {
                baseFont = baseFont.bold()
            }
        }
        if isItalic {
            baseFont = baseFont.italic()
        }
        return baseFont
    }
}
