import SwiftUI

// MARK: - Cyberpunk Neon Theme

struct Neon {
    static let cyan    = Color(red: 0,    green: 0.95, blue: 1)
    static let magenta = Color(red: 1,    green: 0,    blue: 1)
    static let green   = Color(red: 0,    green: 1,    blue: 0.25)
    static let orange  = Color(red: 1,    green: 0.42, blue: 0)
    static let red     = Color(red: 1,    green: 0.18, blue: 0.33)
    static let purple  = Color(red: 0.75, green: 0,    blue: 1)
    static let bg      = Color(red: 0.04, green: 0.04, blue: 0.10)
    static let surface = Color(red: 0.08, green: 0.08, blue: 0.16)

    static let colorMap: [String: Color] = [
        "orange": orange, "blue": cyan, "green": green, "red": red, "purple": purple
    ]
}

// MARK: - Shared UI Components

struct GridBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 44
            let c = Color.cyan.opacity(0.04)
            var x: CGFloat = 0
            while x <= size.width {
                var p = Path(); p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height))
                ctx.stroke(p, with: .color(c), lineWidth: 1); x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                var p = Path(); p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                ctx.stroke(p, with: .color(c), lineWidth: 1); y += step
            }
        }
        .ignoresSafeArea()
    }
}

struct CornerBrackets: View {
    var color: Color = Neon.cyan
    var size: CGFloat = 22
    var body: some View {
        GeometryReader { geo in
            ZStack {
                bracket(color: color, size: size).position(x: 28, y: 60)
                bracket(color: color, size: size).rotationEffect(.degrees(90)).position(x: geo.size.width - 28, y: 60)
                bracket(color: color, size: size).rotationEffect(.degrees(-90)).position(x: 28, y: geo.size.height - 28)
                bracket(color: color, size: size).rotationEffect(.degrees(180)).position(x: geo.size.width - 28, y: geo.size.height - 28)
            }
        }
        .ignoresSafeArea()
    }
    private func bracket(color: Color, size: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(color).frame(width: size, height: 2)
            Rectangle().fill(color).frame(width: 2, height: size)
        }
        .shadow(color: color.opacity(0.9), radius: 4)
    }
}

struct NeonLabel: View {
    let text: String
    var color: Color = Neon.cyan
    var body: some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(color.opacity(0.7))
            .tracking(3)
    }
}

struct NeonDivider: View {
    var color: Color = Neon.cyan
    var body: some View {
        Rectangle()
            .fill(color.opacity(0.3))
            .frame(height: 1)
            .shadow(color: color.opacity(0.6), radius: 2)
    }
}
