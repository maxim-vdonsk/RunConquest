import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @Environment(AppLanguage.self) private var lang
    @State private var currentPage = 0

    struct OnboardPage {
        let icon: String
        let iconColor: Color
        let titleEn: String
        let titleRu: String
        let descEn: String
        let descRu: String
    }

    var pages: [OnboardPage] { [
        OnboardPage(
            icon: "map.fill", iconColor: Neon.cyan,
            titleEn: "CONQUER YOUR CITY",   titleRu: "ЗАВОЮЙ СВОЙ ГОРОД",
            descEn: "Run through the streets and capture territory. The more you run, the more land you own.",
            descRu: "Бегай по улицам и захватывай территорию. Чем больше бегаешь — тем больше земли."
        ),
        OnboardPage(
            icon: "bolt.fill", iconColor: Neon.red,
            titleEn: "ATTACK & DEFEND",     titleRu: "АТАКУЙ И ЗАЩИЩАЙ",
            descEn: "Run through zones held by other players to take them over. Protect your territory by running it again.",
            descRu: "Пробеги через зоны других игроков, чтобы захватить их. Защищай своё — бегая по нему снова."
        ),
        OnboardPage(
            icon: "person.3.fill", iconColor: Neon.magenta,
            titleEn: "JOIN A SQUAD",        titleRu: "ВСТУПАЙ В ОТРЯД",
            descEn: "Team up with friends, share territory, and climb the squad leaderboard together.",
            descRu: "Объединяйся с друзьями, делитесь территорией и вместе покоряйте рейтинг."
        ),
        OnboardPage(
            icon: "trophy.fill", iconColor: Neon.orange,
            titleEn: "COMPLETE CHALLENGES", titleRu: "ВЫПОЛНЯЙ ВЫЗОВЫ",
            descEn: "Monthly operations await. Earn points, unlock badges, and dominate the leaderboard.",
            descRu: "Ежемесячные операции ждут. Зарабатывай очки, открывай значки, доминируй в рейтинге."
        )
    ]}

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        VStack(spacing: 28) {
                            // Icon
                            ZStack {
                                Circle().fill(page.iconColor.opacity(0.1))
                                    .frame(width: 140, height: 140)
                                    .shadow(color: page.iconColor.opacity(0.3), radius: 30)
                                Circle().stroke(page.iconColor.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 110, height: 110)
                                Image(systemName: page.icon)
                                    .font(.system(size: 52, weight: .bold))
                                    .foregroundColor(page.iconColor)
                                    .shadow(color: page.iconColor, radius: 12)
                            }

                            // Text
                            VStack(spacing: 12) {
                                Text(lang.t(page.titleEn, page.titleRu))
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundColor(.white).tracking(3)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: page.iconColor.opacity(0.5), radius: 8)

                                NeonDivider(color: page.iconColor).padding(.horizontal, 60)

                                Text(lang.t(page.descEn, page.descRu))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                Spacer()

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        let isActive = i == currentPage
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isActive ? pages[currentPage].iconColor : Color.gray.opacity(0.3))
                            .frame(width: isActive ? 20 : 6, height: 4)
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Buttons
                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button(action: { withAnimation { currentPage += 1 } }) {
                            Text(lang.t("NEXT →", "ДАЛЕЕ →"))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(Neon.bg).tracking(3)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(pages[currentPage].iconColor)
                                .cornerRadius(6)
                                .shadow(color: pages[currentPage].iconColor.opacity(0.5), radius: 12)
                        }
                        Button(action: { hasSeenOnboarding = true }) {
                            Text(lang.t("SKIP", "ПРОПУСТИТЬ"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.4)).tracking(2)
                        }
                    } else {
                        Button(action: { hasSeenOnboarding = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "flag.checkered.2.crossed")
                                Text(lang.t("START CONQUERING", "НАЧАТЬ ЗАВОЕВАНИЕ"))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced)).tracking(2)
                            }
                            .foregroundColor(Neon.bg)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Neon.cyan, Neon.magenta],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(6)
                            .shadow(color: Neon.cyan.opacity(0.5), radius: 16)
                        }
                    }
                }
                .padding(.horizontal, 32).padding(.bottom, 48)
            }
        }
    }
}
