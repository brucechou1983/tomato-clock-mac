import SwiftUI
import TomatoCore

enum Theme {
    static let background = adaptive(light: 0xFAF8F5, dark: 0x201F1E)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x2B2927)
    static let text = adaptive(light: 0x302B28, dark: 0xF5F0EA)
    static let muted = adaptive(light: 0x766D64, dark: 0xBDB2A8)
    static let line = adaptive(light: 0xE7E0D8, dark: 0x49413B)
    static let track = adaptive(light: 0xEDE7E0, dark: 0x39332E)
    static let tomato = adaptive(light: 0xB94432, dark: 0xEF8C75)
    static let green = adaptive(light: 0x426A4B, dark: 0xA3C5A4)
    static let buttonTomato = Color(hex: 0xB94432)
    static let buttonGreen = Color(hex: 0x426A4B)
    static let tintSurface = adaptive(light: 0xF2EBE3, dark: 0x332D27)

    static func accent(for kind: SessionKind) -> Color { kind == .focus ? tomato : green }
    static func button(for kind: SessionKind) -> Color { kind == .focus ? buttonTomato : buttonGreen }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
                           green: Double((hex >> 8) & 255) / 255,
                           blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct TomatoMark: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.36)
                .fill(Theme.tomato)
                .frame(width: size * 0.82, height: size * 0.70)
                .offset(y: size * 0.12)
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .rotationEffect(.degrees(-35))
                .foregroundStyle(Theme.green)
                .offset(x: size * 0.04, y: -size * 0.23)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.buttonTomato

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.80 : 1), in: Capsule())
            .contentShape(Capsule())
    }
}

struct QuietIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.muted)
            .frame(width: 42, height: 42)
            .background(configuration.isPressed ? Theme.track : Theme.surface, in: Circle())
            .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
            .contentShape(Circle())
    }
}
