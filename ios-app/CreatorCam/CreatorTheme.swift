import SwiftUI

enum CreatorTheme {
    static let cream = Color(hex: "#FBF4E8")
    static let warmCream = Color(hex: "#FFF9F1")
    static let card = Color(hex: "#FFFDF8")
    static let ink = Color(hex: "#241F1C")
    static let muted = Color(hex: "#80766B")
    static let hotPink = Color(hex: "#FF4FA3")
    static let rose = Color(hex: "#D98BAE")
    static let pinkMist = Color(hex: "#FFE8F4")

    static var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    warmCream,
                    cream,
                    pinkMist.opacity(0.45),
                    warmCream
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(hotPink.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 180, y: -260)

            Circle()
                .fill(rose.opacity(0.10))
                .frame(width: 400, height: 400)
                .blur(radius: 90)
                .offset(x: -220, y: 320)
        }
    }
}

struct CreatorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CreatorTheme.hotPink.opacity(configuration.isPressed ? 0.75 : 1.0))
            )
    }
}

struct SecondaryCreatorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(CreatorTheme.ink)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(configuration.isPressed ? CreatorTheme.pinkMist : CreatorTheme.warmCream.opacity(0.86))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.75), lineWidth: 1)
            }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r: UInt64
        let g: UInt64
        let b: UInt64
        let a: UInt64

        switch hex.count {
        case 3:
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17
            a = 255
        case 6:
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            a = 255
        case 8:
            r = int >> 24
            g = (int >> 16) & 0xFF
            b = (int >> 8) & 0xFF
            a = int & 0xFF
        default:
            r = 255
            g = 255
            b = 255
            a = 255
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
