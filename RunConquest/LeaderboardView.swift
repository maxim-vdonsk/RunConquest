import SwiftUI

// MARK: - Leaderboard

struct LeaderboardView: View {
    @State private var players: [PlayerRecord] = []
    @State private var isLoading = true
    let currentPlayer: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("🏆 ЛИДЕРБОРД")
                    .font(.title2.bold()).foregroundColor(.orange).tracking(2).padding(.top, 20)
                if isLoading {
                    Spacer(); ProgressView().tint(.orange); Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                                HStack(spacing: 12) {
                                    Text(medalFor(index)).font(.title2).frame(width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.name).font(.headline)
                                            .foregroundColor(player.name == currentPlayer ? .orange : .white)
                                        Text("\(player.total_runs) пробежек · \(player.total_attacks) атак")
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(String(format: "%.0f м²", player.total_area))
                                            .font(.headline).foregroundColor(.orange)
                                        Text(String(format: "%.1f км", player.total_distance / 1000))
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(player.name == currentPlayer ? Color.orange.opacity(0.15) : Color.white.opacity(0.05))
                                .cornerRadius(14).padding(.horizontal)
                            }
                        }.padding(.top, 8)
                    }
                }
            }
        }
        .task { players = await SupabaseService.shared.fetchLeaderboard(); isLoading = false }
    }

    func medalFor(_ index: Int) -> String {
        switch index { case 0: return "🥇"; case 1: return "🥈"; case 2: return "🥉"; default: return "\(index + 1)" }
    }
}
