import SwiftUI

// MARK: - Leaderboard

struct LeaderboardView: View {
    @State private var players: [PlayerRecord] = []
    @State private var isLoading = true
    let currentPlayer: String

    @Environment(AppLanguage.self) private var lang

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// GLOBAL NETWORK //", "// ГЛОБАЛЬНАЯ СЕТЬ //"))
                    Text(lang.t("RANKINGS", "РЕЙТИНГ"))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(6)
                        .shadow(color: Neon.cyan, radius: 8)
                    NeonDivider().padding(.horizontal, 40)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(Neon.cyan)
                        Text(lang.t("SYNCING DATA...", "ЗАГРУЗКА ДАННЫХ..."))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Neon.cyan.opacity(0.5))
                            .tracking(3)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                                RankRow(index: index, player: player, isMe: player.name == currentPlayer)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .task { players = await SupabaseService.shared.fetchLeaderboard(); isLoading = false }
    }
}

struct RankRow: View {
    let index: Int
    let player: PlayerRecord
    let isMe: Bool

    @Environment(AppLanguage.self) private var lang

    var rankColor: Color {
        switch index {
        case 0: return Neon.orange
        case 1: return Color(white: 0.8)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Neon.cyan.opacity(0.5)
        }
    }

    var rankLabel: String {
        switch index {
        case 0: return "#01"
        case 1: return "#02"
        case 2: return "#03"
        default: return String(format: "#%02d", index + 1)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(rankLabel)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(rankColor)
                .shadow(color: index < 3 ? rankColor : .clear, radius: 6)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(player.name.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isMe ? Neon.cyan : .white)
                    .shadow(color: isMe ? Neon.cyan.opacity(0.6) : .clear, radius: 4)
                Text("\(player.total_runs) \(lang.t("RUNS", "ЗАБ.")) · \(player.total_attacks) \(lang.t("ATTACKS", "АТА."))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .tracking(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.0f M²", player.total_area))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isMe ? Neon.cyan : Neon.orange)
                    .shadow(color: (isMe ? Neon.cyan : Neon.orange).opacity(0.5), radius: 4)
                Text(String(format: "%.1f KM", player.total_distance / 1000))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(isMe ? Neon.cyan.opacity(0.07) : Neon.surface.opacity(0.6))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isMe ? Neon.cyan.opacity(0.5) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}
