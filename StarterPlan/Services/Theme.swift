import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x141618)
    static let surface = Color(hex: 0x1E2124)
    static let surfaceHigh = Color(hex: 0x272B2F)
    static let accent = Color(hex: 0x25E58B)          // vibrant mint-green
    static let accentDim = Color(hex: 0x17A163)
    static let teal = Color(hex: 0x24D6D6)
    static let text = Color(hex: 0xECEFF1)
    static let textDim = Color(hex: 0x9AA3AA)
    static let locked = Color(hex: 0x33383D)
    static let flame = Color(hex: 0xFF8A3D)
    static let gold = Color(hex: 0xFFC738)
    static let danger = Color(hex: 0xFF5C5C)

    static let corner: CGFloat = 20
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

struct CardBackground: ViewModifier {
    var color: Color = Theme.surface
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(color))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

extension View {
    func card(_ color: Color = Theme.surface) -> some View { modifier(CardBackground(color: color)) }
}

/// Chunky Duolingo-style button with a bottom "lip".
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    var textColor: Color = Color(hex: 0x10221A)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color)
                    .shadow(color: color.opacity(0.35), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
