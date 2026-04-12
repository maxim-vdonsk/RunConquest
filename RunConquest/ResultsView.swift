import SwiftUI

// MARK: - Results

struct ResultsView: View {
    let playerName: String
    let distance: Double
    let area: Double
    let points: Int
    let color: String
    let attackedCount: Int
    let onRestart: () -> Void
    let colorMap: [String: Color] = ["orange": .orange, "blue": .blue, "green": .green, "red": .red, "purple": .purple]
    @State private var appeared = false

    var level: String {
        switch points {
        case 0..<100: return "🥉 Новичок"
        case 100..<500: return "🥈 Боец"
        case 500..<1000: return "🥇 Воин"
        default: return "👑 Завоеватель"
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Circle().fill((colorMap[color] ?? .orange).opacity(0.15))
                .frame(width: 300, height: 300).blur(radius: 80)
            VStack(spacing: 24) {
                Text("ПРОБЕЖКА ЗАВЕРШЕНА").font(.title2.bold())
                    .foregroundColor(colorMap[color] ?? .orange).tracking(2)
                    .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)
                Text(level).font(.system(size: 64)).foregroundColor(.white)
                    .scaleEffect(appeared ? 1 : 0.5).opacity(appeared ? 1 : 0)
                Text(playerName).font(.title3.bold()).foregroundColor(.white).opacity(appeared ? 1 : 0)
                VStack(spacing: 16) {
                    ResultRow(icon: "figure.run", title: "Дистанция", value: String(format: "%.2f км", distance / 1000))
                    ResultRow(icon: "map.fill", title: "Территория", value: String(format: "%.0f м²", area))
                    ResultRow(icon: "star.fill", title: "Очки", value: "\(points) pts")
                    if attackedCount > 0 {
                        ResultRow(icon: "bolt.fill", title: "Атаковано зон", value: "⚔️ \(attackedCount)")
                    }
                }
                .padding().background(Color.white.opacity(0.07)).cornerRadius(20).padding(.horizontal)
                .offset(y: appeared ? 0 : 30).opacity(appeared ? 1 : 0)
                Button(action: onRestart) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Новая пробежка").bold()
                    }
                    .foregroundColor(.black).frame(maxWidth: .infinity).padding()
                    .background(colorMap[color] ?? .orange).cornerRadius(16).padding(.horizontal)
                    .shadow(color: (colorMap[color] ?? .orange).opacity(0.4), radius: 12)
                }
                .offset(y: appeared ? 0 : 30).opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) { appeared = true }
        }
    }
}

// MARK: - Result Row

struct ResultRow: View {
    let icon: String; let title: String; let value: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.orange).frame(width: 28)
            Text(title).foregroundColor(.gray); Spacer()
            Text(value).bold().foregroundColor(.white)
        }
    }
}
