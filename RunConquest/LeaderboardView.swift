import SwiftUI

// MARK: - Leaderboard

struct LeaderboardView: View {
    let currentPlayer: String
    @Environment(AppLanguage.self) private var lang
    @State private var tab: LTab = .global
    @State private var globalPlayers: [PlayerRecord] = []
    @State private var friendsPlayers: [PlayerRecord] = []
    @State private var cityPlayers: [PlayerRecord] = []
    @State private var isLoading = true

    enum LTab { case global, friends, city }

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
                        .foregroundColor(.white).tracking(6)
                        .shadow(color: Neon.cyan, radius: 8)
                    NeonDivider().padding(.horizontal, 40)
                }
                .padding(.top, 24).padding(.bottom, 12)

                // Tab bar
                HStack(spacing: 0) {
                    ForEach([
                        (LTab.global,  lang.t("GLOBAL",  "ГЛОБАЛ"),  "globe"),
                        (LTab.friends, lang.t("FRIENDS", "ДРУЗЬЯ"),  "person.2.fill"),
                        (LTab.city,    lang.t("CITY",    "ГОРОД"),   "building.2.fill")
                    ], id: \.1) { (t, label, icon) in
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { tab = t } }) {
                            VStack(spacing: 4) {
                                Image(systemName: icon).font(.system(size: 12))
                                    .foregroundColor(tab == t ? Neon.cyan : .gray.opacity(0.4))
                                Text(label)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(tab == t ? Neon.cyan : .gray.opacity(0.4))
                                    .tracking(1)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(tab == t ? Neon.cyan.opacity(0.08) : Color.clear)
                            .overlay(alignment: .bottom) {
                                if tab == t {
                                    Rectangle().fill(Neon.cyan).frame(height: 2)
                                }
                            }
                        }
                    }
                }
                .background(Neon.surface.opacity(0.4))
                .padding(.horizontal)
                .padding(.bottom, 8)

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(Neon.cyan)
                        Text(lang.t("SYNCING DATA...", "ЗАГРУЗКА ДАННЫХ..."))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Neon.cyan.opacity(0.5)).tracking(3)
                    }
                    Spacer()
                } else {
                    let list: [PlayerRecord] = {
                        switch tab {
                        case .global:  return globalPlayers
                        case .friends: return friendsPlayers
                        case .city:    return cityPlayers
                        }
                    }()

                    if list.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 40)).foregroundColor(Neon.cyan.opacity(0.3))
                            Text(lang.t("NO DATA YET", "ДАННЫХ НЕТ"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.4)).tracking(2)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 4) {
                                ForEach(Array(list.enumerated()), id: \.offset) { index, player in
                                    RankRow(index: index, player: player, isMe: player.name == currentPlayer)
                                }
                            }
                            .padding(.horizontal).padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .task { await loadAll() }
    }

    private func loadAll() async {
        isLoading = true
        async let g = SupabaseService.shared.fetchLeaderboard()
        async let f = SupabaseService.shared.fetchLeaderboardFriends(playerName: currentPlayer)
        async let c = SupabaseService.shared.fetchLeaderboardByCity(playerName: currentPlayer)
        let (gp, fp, cp) = await (g, f, c)
        globalPlayers = gp
        friendsPlayers = fp
        cityPlayers = cp
        isLoading = false
    }
}

// MARK: - Rank Row

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

    var rankLabel: String { String(format: "#%02d", index + 1) }

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
                    .foregroundColor(.gray.opacity(0.5)).tracking(1)
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
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(isMe ? Neon.cyan.opacity(0.5) : Color.white.opacity(0.04), lineWidth: 1))
    }
}
