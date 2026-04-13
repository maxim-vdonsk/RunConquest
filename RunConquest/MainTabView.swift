import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @AppStorage("playerName") private var playerName: String = ""
    @AppStorage("playerColor") private var playerColor: String = "orange"
    @AppStorage("isRunActive") private var isRunActive: Bool = false
    @Environment(AppLanguage.self) private var lang
    @State private var selectedTab: AppTab = .map

    enum AppTab: Int, CaseIterable {
        case map, feed, rankings, plans, profile

        func label(_ lang: AppLanguage) -> String {
            switch self {
            case .map:      return lang.t("MAP", "КАРТА")
            case .feed:     return lang.t("FEED", "ЛЕНТА")
            case .rankings: return lang.t("TOP", "ТОП")
            case .plans:    return lang.t("PLANS", "ПЛАНЫ")
            case .profile:  return lang.t("PROFILE", "ПРОФИЛЬ")
            }
        }

        var icon: String {
            switch self {
            case .map:      return "map.fill"
            case .feed:     return "antenna.radiowaves.left.and.right"
            case .rankings: return "trophy.fill"
            case .plans:    return "calendar"
            case .profile:  return "person.fill"
            }
        }

        var accent: Color {
            switch self {
            case .map:      return Neon.cyan
            case .feed:     return Neon.green
            case .rankings: return Neon.orange
            case .plans:    return Neon.magenta
            case .profile:  return Neon.cyan
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ContentView()
                    .tag(AppTab.map)
                    .toolbarBackground(.hidden, for: .tabBar)

                FeedView(playerName: playerName)
                    .tag(AppTab.feed)
                    .toolbarBackground(.hidden, for: .tabBar)

                LeaderboardView(currentPlayer: playerName)
                    .tag(AppTab.rankings)
                    .toolbarBackground(.hidden, for: .tabBar)

                TrainingPlanView(playerName: playerName)
                    .tag(AppTab.plans)
                    .toolbarBackground(.hidden, for: .tabBar)

                ProfileView(
                    playerName: playerName,
                    color: playerColor,
                    savedName: .constant(playerName),
                    savedColor: .constant(playerColor)
                )
                .tag(AppTab.profile)
                .toolbarBackground(.hidden, for: .tabBar)
            }
            .tabViewStyle(.automatic)

            // Custom cyberpunk tab bar (hidden during active run)
            if !isRunActive && !playerName.isEmpty {
                CyberpunkTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: isRunActive)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Cyberpunk Tab Bar

struct CyberpunkTabBar: View {
    @Binding var selectedTab: MainTabView.AppTab
    @Environment(AppLanguage.self) private var lang

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.AppTab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
                    tabItem(tab: tab)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(
            ZStack {
                Neon.bg.opacity(0.92)
                Rectangle().fill(.ultraThinMaterial).opacity(0.3)
            }
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [selectedTab.accent.opacity(0.6), selectedTab.accent.opacity(0.1), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 20, y: -8)
    }

    private func tabItem(tab: MainTabView.AppTab) -> some View {
        let isSelected = selectedTab == tab
        return VStack(spacing: 5) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tab.accent.opacity(0.12))
                        .frame(width: 40, height: 32)
                }
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? tab.accent : Color.gray.opacity(0.35))
                    .shadow(color: isSelected ? tab.accent.opacity(0.8) : .clear, radius: 6)
            }
            Text(tab.label(lang))
                .font(.system(size: 7, weight: isSelected ? .bold : .regular, design: .monospaced))
                .foregroundColor(isSelected ? tab.accent : Color.gray.opacity(0.35))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
