import SwiftUI

// MARK: - Profile View

struct ProfileView: View {
    let playerName: String
    let color: String
    @Binding var savedName: String
    @Binding var savedColor: String
    @State private var player: PlayerRecord? = nil
    @State private var myRuns: [RunRecord] = []
    @State private var isLoading = true
    @State private var editingName = false
    @State private var tempName = ""
    @Environment(\.dismiss) var dismiss

    let colorMap: [String: Color] = ["orange": .orange, "blue": .blue, "green": .green, "red": .red, "purple": .purple]
    let colors = ["orange", "blue", "green", "red", "purple"]

    var level: (String, Color) {
        switch player?.total_area ?? 0 {
        case 0..<10000: return ("🥉 Новичок", .gray)
        case 10000..<50000: return ("🥈 Боец", .blue)
        case 50000..<200000: return ("🥇 Воин", .orange)
        default: return ("👑 Завоеватель", .yellow)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.orange)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle().fill((colorMap[savedColor] ?? .orange).opacity(0.2))
                                .frame(width: 100, height: 100).blur(radius: 15)
                            Circle().fill(colorMap[savedColor] ?? .orange).frame(width: 80, height: 80)
                            Text(String(savedName.prefix(1)).uppercased())
                                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                        }
                        .padding(.top, 24)

                        if editingName {
                            HStack {
                                TextField("Имя", text: $tempName)
                                    .font(.title2.bold()).foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(8).background(Color.white.opacity(0.1)).cornerRadius(10)
                                Button("OK") {
                                    if !tempName.isEmpty {
                                        savedName = tempName
                                        UserDefaults.standard.set(tempName, forKey: "playerName")
                                    }
                                    editingName = false
                                }
                                .foregroundColor(.orange).bold()
                            }
                            .padding(.horizontal, 40)
                        } else {
                            HStack(spacing: 8) {
                                Text(savedName).font(.title2.bold()).foregroundColor(.white)
                                Button(action: { tempName = savedName; editingName = true }) {
                                    Image(systemName: "pencil").foregroundColor(.gray)
                                }
                            }
                        }

                        Text(level.0).font(.headline).foregroundColor(level.1)

                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { c in
                                Circle().fill(colorMap[c] ?? .orange).frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.white, lineWidth: savedColor == c ? 2.5 : 0))
                                    .scaleEffect(savedColor == c ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3), value: savedColor)
                                    .onTapGesture {
                                        savedColor = c
                                        UserDefaults.standard.set(c, forKey: "playerColor")
                                    }
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(icon: "figure.run", title: "Пробежек", value: "\(player?.total_runs ?? 0)")
                            StatCard(icon: "map.fill", title: "Территория", value: String(format: "%.0f м²", player?.total_area ?? 0))
                            StatCard(icon: "road.lanes", title: "Дистанция", value: String(format: "%.1f км", (player?.total_distance ?? 0) / 1000))
                            StatCard(icon: "bolt.fill", title: "Атак", value: "\(player?.total_attacks ?? 0)")
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("История пробежек").font(.headline).foregroundColor(.white).padding(.horizontal)
                            ForEach(myRuns) { run in
                                HStack {
                                    Circle().fill(colorMap[run.color] ?? .orange).frame(width: 10, height: 10)
                                    Text(formatDate(run.created_at ?? "")).foregroundColor(.gray).font(.caption)
                                    Spacer()
                                    Text(run.is_active == true ? "🟢 Активна" : "⚫ Завоёвана")
                                        .font(.caption).foregroundColor(run.is_active == true ? .green : .gray)
                                }
                                .padding(.horizontal).padding(.vertical, 8)
                                .background(Color.white.opacity(0.05)).cornerRadius(10).padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .task {
            async let p = SupabaseService.shared.fetchLeaderboard()
            async let r = SupabaseService.shared.fetchMyRuns(playerName: savedName)
            let (players, runs) = await (p, r)
            player = players.first(where: { $0.name == savedName })
            myRuns = runs
            isLoading = false
        }
    }

    func formatDate(_ dateStr: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: dateStr) else { return dateStr }
        let d = DateFormatter(); d.dateFormat = "dd MMM, HH:mm"; d.locale = Locale(identifier: "ru_RU")
        return d.string(from: date)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String; let title: String; let value: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.orange).font(.title2)
            Text(value).font(.title3.bold()).foregroundColor(.white)
            Text(title).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color.white.opacity(0.07)).cornerRadius(16)
    }
}
