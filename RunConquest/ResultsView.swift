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

    @Environment(AppLanguage.self) private var lang

    @State private var appeared = false

    var accent: Color { Neon.colorMap[color] ?? Neon.cyan }

    var levelData: (String, Color) {
        switch points {
        case 0..<100:   return (lang.t("ROOKIE",    "НОВИЧОК"),    .gray)
        case 100..<500: return (lang.t("FIGHTER",   "БОЕЦ"),       Neon.cyan)
        case 500..<1000:return (lang.t("WARRIOR",   "ВОИН"),       Neon.orange)
        default:        return (lang.t("CONQUEROR", "ЗАВОЕВАТЕЛЬ"),Neon.magenta)
        }
    }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()
            CornerBrackets(color: accent)

            // Glow orb
            Circle()
                .fill(accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 60)

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// MISSION REPORT //", "// ОТЧЁТ МИССИИ //"), color: accent)
                    Text(lang.t("RUN COMPLETE", "ЗАБЕГ ЗАВЕРШЁН"))
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)
                        .shadow(color: accent, radius: 8)
                    NeonDivider(color: accent).padding(.horizontal, 30)
                }
                .scaleEffect(appeared ? 1 : 0.9).opacity(appeared ? 1 : 0)

                // Level badge
                VStack(spacing: 4) {
                    Text(levelData.0)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(levelData.1)
                        .tracking(6)
                        .shadow(color: levelData.1, radius: 12)
                    Text(lang.t("RANK ACHIEVED", "РАНГ ПОЛУЧЕН"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(levelData.1.opacity(0.6))
                        .tracking(4)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(levelData.1.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(levelData.1.opacity(0.4), lineWidth: 1))
                .padding(.horizontal)
                .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)

                // Stats terminal
                VStack(spacing: 0) {
                    terminalHeader
                    VStack(spacing: 1) {
                        TerminalRow(key: lang.t("OPERATOR",  "ИГРОК"),      value: playerName,                                 color: accent)
                        TerminalRow(key: lang.t("DISTANCE",  "ДИСТАНЦИЯ"),  value: String(format: "%.2f KM", distance / 1000), color: .white)
                        TerminalRow(key: lang.t("TERRITORY", "ТЕРРИТОРИЯ"), value: String(format: "%.0f M²", area),            color: .white)
                        TerminalRow(key: lang.t("SCORE",     "ОЧКИ"),       value: "\(points) \(lang.t("PTS", "ОЧК"))",        color: Neon.green)
                        if attackedCount > 0 {
                            TerminalRow(key: lang.t("ZONES HIT", "ЗОН ЗАХВАЧЕНО"), value: "⚔ \(attackedCount)", color: Neon.red)
                        }
                    }
                }
                .padding(.horizontal)
                .offset(y: appeared ? 0 : 30).opacity(appeared ? 1 : 0)

                // Restart button
                Button(action: onRestart) {
                    Text(lang.t("[ NEW MISSION  ▶ ]", "[ НОВАЯ МИССИЯ  ▶ ]"))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Neon.bg)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accent)
                        .cornerRadius(4)
                        .shadow(color: accent.opacity(0.7), radius: 14)
                        .padding(.horizontal)
                }
                .offset(y: appeared ? 0 : 30).opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) { appeared = true }
        }
    }

    private var terminalHeader: some View {
        HStack {
            Text(lang.t("// STATS LOG", "// СТАТИСТИКА"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(accent.opacity(0.5))
                .tracking(3)
            Spacer()
            Text(lang.t("[ END ]", "[ КОНЕЦ ]"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(accent.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(accent.opacity(0.06))
    }
}

struct TerminalRow: View {
    let key: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 120, alignment: .leading)
            Text("//")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.3))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color == .white ? .clear : color.opacity(0.6), radius: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.02))
    }
}
