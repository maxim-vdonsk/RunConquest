import SwiftUI

// MARK: - Profile View

struct ProfileView: View {
    let playerName: String
    let color: String
    @Binding var savedName: String
    @Binding var savedColor: String

    @Environment(AppLanguage.self) private var lang
    @State private var player: PlayerRecord? = nil
    @State private var myRuns: [RunRecord] = []
    @State private var isLoading = true
    @State private var editingName = false
    @State private var tempName = ""
    @Environment(\.dismiss) var dismiss

    let colors = ["orange", "blue", "green", "red", "purple"]
    let colorLabelsEN = ["orange": "AMBER",   "blue": "CYAN",  "green": "MATRIX", "red": "CRIMSON", "purple": "VIOLET"]
    let colorLabelsRU = ["orange": "ЯНТАРЬ", "blue": "ЦИАН", "green": "МАТРИЦА", "red": "БАГРЯНЕЦ", "purple": "ФИОЛЕТ"]

    var accent: Color { Neon.colorMap[savedColor] ?? Neon.cyan }

    var levelData: (String, Color) {
        switch player?.total_area ?? 0 {
        case 0..<10000:    return (lang.t("ROOKIE",    "НОВИЧОК"),    .gray)
        case 10000..<50000: return (lang.t("FIGHTER",  "БОЕЦ"),       Neon.cyan)
        case 50000..<200000:return (lang.t("WARRIOR",  "ВОИН"),       Neon.orange)
        default:            return (lang.t("CONQUEROR","ЗАВОЕВАТЕЛЬ"),Neon.magenta)
        }
    }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(Neon.cyan)
                    Text(lang.t("LOADING PROFILE...", "ЗАГРУЗКА ПРОФИЛЯ..."))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Neon.cyan.opacity(0.5))
                        .tracking(3)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.12))
                                .frame(width: 110, height: 110)
                                .shadow(color: accent.opacity(0.5), radius: 20)
                            Circle()
                                .stroke(accent.opacity(0.6), lineWidth: 2)
                                .frame(width: 90, height: 90)
                                .shadow(color: accent, radius: 6)
                            Text(String(savedName.prefix(1)).uppercased())
                                .font(.system(size: 38, weight: .black, design: .monospaced))
                                .foregroundColor(accent)
                                .shadow(color: accent, radius: 8)
                        }
                        .padding(.top, 24)

                        // Name
                        if editingName {
                            HStack {
                                TextField(lang.t("CALLSIGN", "ПОЗЫВНОЙ"), text: $tempName)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(10)
                                    .background(Neon.surface)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.6), lineWidth: 1))
                                Button("OK") {
                                    if !tempName.isEmpty {
                                        savedName = tempName
                                        UserDefaults.standard.set(tempName, forKey: "playerName")
                                    }
                                    editingName = false
                                }
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(accent)
                            }
                            .padding(.horizontal, 40)
                        } else {
                            HStack(spacing: 10) {
                                Text(savedName.uppercased())
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .shadow(color: accent.opacity(0.5), radius: 4)
                                Button(action: { tempName = savedName; editingName = true }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                        .foregroundColor(accent.opacity(0.7))
                                }
                            }
                        }

                        // Level badge
                        Text(levelData.0)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(levelData.1)
                            .tracking(4)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(levelData.1.opacity(0.1))
                            .cornerRadius(3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(levelData.1.opacity(0.4), lineWidth: 1))
                            .shadow(color: levelData.1.opacity(0.4), radius: 6)

                        NeonDivider(color: accent).padding(.horizontal, 20)

                        // Language selector
                        VStack(spacing: 8) {
                            NeonLabel(text: lang.t("> LANGUAGE:", "> ЯЗЫК:"), color: accent)
                            HStack(spacing: 0) {
                                ForEach(["ru", "en"], id: \.self) { code in
                                    let isSelected = lang.code == code
                                    let label = code == "ru" ? "RU  РУССКИЙ" : "EN  ENGLISH"
                                    Button(action: { lang.set(code) }) {
                                        Text(label)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(isSelected ? Neon.bg : accent.opacity(0.5))
                                            .tracking(1)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? accent : accent.opacity(0.07))
                                            .cornerRadius(3)
                                    }
                                    .animation(.easeInOut(duration: 0.2), value: lang.code)
                                    if code == "ru" {
                                        Rectangle()
                                            .fill(accent.opacity(0.2))
                                            .frame(width: 1)
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(accent.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.horizontal)

                        NeonDivider(color: accent).padding(.horizontal, 20)

                        // Color selector
                        VStack(spacing: 8) {
                            NeonLabel(text: lang.t("> FACTION COLOR:", "> ЦВЕТ ФРАКЦИИ:"), color: accent)
                            HStack(spacing: 0) {
                                ForEach(colors, id: \.self) { c in
                                    let col = Neon.colorMap[c] ?? Neon.cyan
                                    let isSelected = savedColor == c
                                    let labels = lang.code == "ru" ? colorLabelsRU : colorLabelsEN
                                    VStack(spacing: 4) {
                                        Circle().fill(col).frame(width: 32, height: 32)
                                            .shadow(color: isSelected ? col : .clear, radius: 10)
                                            .overlay(Circle().stroke(Color.white.opacity(isSelected ? 1 : 0), lineWidth: 2))
                                            .scaleEffect(isSelected ? 1.2 : 1.0)
                                            .animation(.spring(response: 0.25), value: savedColor)
                                        Text(labels[c] ?? "")
                                            .font(.system(size: 6, design: .monospaced))
                                            .foregroundColor(isSelected ? col : .gray.opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture {
                                        savedColor = c
                                        UserDefaults.standard.set(c, forKey: "playerColor")
                                    }
                                }
                            }
                        }

                        NeonDivider(color: accent).padding(.horizontal, 20)

                        // Stats grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            CyberStatCard(icon: "figure.run",  label: lang.t("RUNS",      "ЗАБЕГОВ"),    value: "\(player?.total_runs ?? 0)")
                            CyberStatCard(icon: "map.fill",    label: lang.t("TERRITORY", "ТЕРРИТОРИЯ"), value: String(format: "%.0f M²", player?.total_area ?? 0))
                            CyberStatCard(icon: "road.lanes",  label: lang.t("DISTANCE",  "ДИСТАНЦИЯ"),  value: String(format: "%.1f KM", (player?.total_distance ?? 0) / 1000))
                            CyberStatCard(icon: "bolt.fill",   label: lang.t("ATTACKS",   "АТАК"),       value: "\(player?.total_attacks ?? 0)", color: Neon.red)
                        }
                        .padding(.horizontal)

                        // Run history
                        VStack(alignment: .leading, spacing: 6) {
                            NeonLabel(text: lang.t("> RUN HISTORY:", "> ИСТОРИЯ ЗАБЕГОВ:"), color: accent).padding(.horizontal)
                            ForEach(myRuns) { run in
                                HStack {
                                    Circle().fill(Neon.colorMap[run.color] ?? Neon.cyan)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: Neon.colorMap[run.color] ?? Neon.cyan, radius: 3)
                                    Text(formatDate(run.created_at ?? ""))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.6))
                                    Spacer()
                                    Text(run.is_active == true ? lang.t("ACTIVE", "АКТИВНЫЙ") : lang.t("CAPTURED", "ЗАХВАЧЕН"))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(run.is_active == true ? Neon.green : .gray.opacity(0.4))
                                        .shadow(color: run.is_active == true ? Neon.green.opacity(0.5) : .clear, radius: 3)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Neon.surface.opacity(0.5))
                                .cornerRadius(3)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
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
        let d = DateFormatter()
        d.dateFormat = "dd MMM, HH:mm"
        d.locale = Locale(identifier: lang.code == "ru" ? "ru_RU" : "en_US")
        return d.string(from: date).uppercased()
    }
}

// MARK: - Stat Card

struct CyberStatCard: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = Neon.cyan

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .shadow(color: color.opacity(0.7), radius: 4)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Neon.surface)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// Keep StatCard alias for backwards compatibility
typealias StatCard = CyberStatCard
