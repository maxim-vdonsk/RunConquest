import SwiftUI

// MARK: - Challenges View

struct ChallengesView: View {
    let playerName: String
    @Environment(AppLanguage.self) private var lang
    @State private var challenges: [Challenge] = []
    @State private var progress: [String: ChallengeProgress] = [:]
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// OPERATIONS //", "// ОПЕРАЦИИ //"))
                    Text(lang.t("CHALLENGES", "ВЫЗОВЫ"))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(6)
                        .shadow(color: Neon.orange, radius: 8)
                    NeonDivider(color: Neon.orange).padding(.horizontal, 40)
                }
                .padding(.top, 24).padding(.bottom, 16)

                if isLoading {
                    Spacer()
                    ProgressView().tint(Neon.orange)
                    Spacer()
                } else if challenges.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "trophy").font(.system(size: 44))
                            .foregroundColor(Neon.orange.opacity(0.3))
                        Text(lang.t("NO CHALLENGES YET", "ВЫЗОВОВ НЕТ"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.4)).tracking(2)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(challenges) { challenge in
                                ChallengeCard(
                                    challenge: challenge,
                                    progress: challenge.id.flatMap { progress[$0] }
                                )
                            }
                        }
                        .padding(.horizontal).padding(.bottom, 32)
                    }
                }
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        let ch = await SupabaseService.shared.fetchChallenges()
        let ids = ch.compactMap(\.id)
        let progList = await SupabaseService.shared.fetchChallengeProgress(playerName: playerName, challengeIds: ids)
        challenges = ch
        progress = Dictionary(uniqueKeysWithValues: progList.map { ($0.challenge_id, $0) })
        isLoading = false
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let challenge: Challenge
    let progress: ChallengeProgress?
    @Environment(AppLanguage.self) private var lang

    var current: Double { progress?.current_value ?? 0 }
    var target: Double { challenge.target_value }
    var pct: Double { min(1.0, target > 0 ? current / target : 0) }
    var isDone: Bool { pct >= 1.0 }

    var accent: Color {
        switch challenge.type {
        case "distance":   return Neon.cyan
        case "attacks":    return Neon.red
        case "runs":       return Neon.green
        case "territory":  return Neon.orange
        default:           return Neon.magenta
        }
    }

    var icon: String {
        switch challenge.type {
        case "distance":   return "figure.run"
        case "attacks":    return "bolt.fill"
        case "runs":       return "flag.fill"
        case "territory":  return "map.fill"
        default:           return "star.fill"
        }
    }

    var formattedTarget: String {
        switch challenge.type {
        case "distance": return String(format: "%.0f KM", target / 1000)
        case "territory":return String(format: "%.0f M²", target)
        default:         return String(format: "%.0f", target)
        }
    }

    var formattedCurrent: String {
        switch challenge.type {
        case "distance": return String(format: "%.1f KM", current / 1000)
        case "territory":return String(format: "%.0f M²", current)
        default:         return String(format: "%.0f", current)
        }
    }

    var title: String { lang.t(challenge.title_en, challenge.title_ru) }
    var desc: String? {
        let d = lang.t(challenge.description_en ?? "", challenge.description_ru ?? "")
        return d.isEmpty ? nil : d
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(accent.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 18, weight: .bold))
                        .foregroundColor(isDone ? Neon.orange : accent)
                        .shadow(color: (isDone ? Neon.orange : accent).opacity(0.6), radius: 6)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isDone ? Neon.orange : .white)
                    if let d = desc {
                        Text(d)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.45))
                            .lineLimit(2)
                    }
                }
                Spacer()
                if isDone {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Neon.orange)
                        .shadow(color: Neon.orange.opacity(0.6), radius: 8)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(formattedCurrent)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(accent)
                    Spacer()
                    Text(formattedTarget)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.05)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isDone ?
                                LinearGradient(colors: [Neon.orange, Neon.red], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [accent, accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * pct, height: 6)
                            .shadow(color: accent.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 6)
            }

            // Bottom row
            HStack {
                Label("\(Int(pct * 100))%", systemImage: "chart.bar.fill")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(accent.opacity(0.7))
                Spacer()
                if let badge = challenge.reward_badge, !badge.isEmpty {
                    HStack(spacing: 4) {
                        Text(badge).font(.system(size: 14))
                        Text(lang.t("badge", "значок"))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Neon.orange)
                    }
                }
                Text("\(challenge.month)/\(challenge.year)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
        .padding(14)
        .background(Neon.surface.opacity(isDone ? 0.8 : 0.6))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(isDone ? Neon.orange.opacity(0.25) : accent.opacity(0.12), lineWidth: 1))
    }
}
