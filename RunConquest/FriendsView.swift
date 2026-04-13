import SwiftUI

// MARK: - Friends View

struct FriendsView: View {
    let playerName: String
    @Environment(AppLanguage.self) private var lang
    @State private var searchQuery = ""
    @State private var searchResults: [PlayerRecord] = []
    @State private var following: [FriendRecord] = []
    @State private var followers: [FriendRecord] = []
    @State private var followingNames: Set<String> = []
    @State private var isSearching = false
    @State private var tab: FTab = .following
    @State private var selectedPlayer: PlayerRecord? = nil

    enum FTab { case following, followers, search }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// NETWORK //", "// СЕТЬ //"))
                    Text(lang.t("FRIENDS", "ДРУЗЬЯ"))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(6)
                        .shadow(color: Neon.cyan, radius: 8)
                    NeonDivider().padding(.horizontal, 40)
                }
                .padding(.top, 24).padding(.bottom, 12)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Neon.cyan.opacity(0.6))
                    TextField(lang.t("Search player...", "Поиск игрока..."), text: $searchQuery)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .onChange(of: searchQuery) { performSearch() }
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = ""; searchResults = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Neon.surface)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Neon.cyan.opacity(0.2), lineWidth: 1))
                .padding(.horizontal).padding(.bottom, 12)

                if !searchQuery.isEmpty {
                    searchResultsList
                } else {
                    tabBar
                    tabContent
                }
            }
        }
        .sheet(item: $selectedPlayer) { player in
            PlayerProfileView(player: player, myName: playerName, isFollowing: followingNames.contains(player.name))
        }
        .task { await loadData() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([(FTab.following, lang.t("FOLLOWING", "ПОДПИСКИ"), following.count),
                     (FTab.followers, lang.t("FOLLOWERS", "ПОДПИСЧИКИ"), followers.count)],
                    id: \.1) { (t, label, count) in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { tab = t } }) {
                    VStack(spacing: 3) {
                        Text("\(count)")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(tab == t ? Neon.cyan : .white)
                        Text(label)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(tab == t ? Neon.cyan : .gray.opacity(0.5))
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
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 4) {
                let list: [String] = tab == .following
                    ? following.map(\.following_name)
                    : followers.map(\.follower_name)
                if list.isEmpty {
                    emptyState
                } else {
                    ForEach(list, id: \.self) { name in
                        FriendRow(
                            name: name,
                            isFollowing: followingNames.contains(name),
                            myName: playerName,
                            onToggle: { await toggleFollow(name: name) },
                            onTap: { fetchAndOpen(name: name) }
                        )
                    }
                }
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 24)
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 4) {
                if isSearching {
                    ProgressView().tint(Neon.cyan).padding(.top, 40)
                } else if searchResults.isEmpty {
                    emptyState
                } else {
                    ForEach(searchResults) { player in
                        FriendRow(
                            name: player.name,
                            isFollowing: followingNames.contains(player.name),
                            myName: playerName,
                            onToggle: { await toggleFollow(name: player.name) },
                            onTap: { selectedPlayer = player }
                        )
                    }
                }
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 36)).foregroundColor(Neon.cyan.opacity(0.3))
                .padding(.top, 40)
            Text(lang.t("NO PLAYERS FOUND", "ИГРОКИ НЕ НАЙДЕНЫ"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.4)).tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func loadData() async {
        async let f = SupabaseService.shared.fetchFollowing(playerName: playerName)
        async let r = SupabaseService.shared.fetchFollowers(playerName: playerName)
        let (fo, fr) = await (f, r)
        following = fo; followers = fr
        followingNames = Set(fo.map(\.following_name))
    }

    private func performSearch() {
        guard searchQuery.count >= 2 else { searchResults = []; return }
        isSearching = true
        Task {
            let results = await SupabaseService.shared.searchPlayers(query: searchQuery)
            searchResults = results.filter { $0.name != playerName }
            isSearching = false
        }
    }

    private func toggleFollow(name: String) async {
        if followingNames.contains(name) {
            await SupabaseService.shared.unfollowPlayer(from: playerName, to: name)
            followingNames.remove(name)
            following.removeAll { $0.following_name == name }
        } else {
            await SupabaseService.shared.followPlayer(from: playerName, to: name)
            followingNames.insert(name)
        }
        await loadData()
    }

    private func fetchAndOpen(name: String) {
        Task {
            if let p = await SupabaseService.shared.fetchPlayer(name: name) {
                selectedPlayer = p
            }
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let name: String
    let isFollowing: Bool
    let myName: String
    let onToggle: () async -> Void
    let onTap: () -> Void
    @Environment(AppLanguage.self) private var lang
    @State private var loading = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                ZStack {
                    Circle().fill(Neon.cyan.opacity(0.12)).frame(width: 38, height: 38)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(Neon.cyan)
                }
            }
            Button(action: onTap) {
                Text(name.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: {
                loading = true
                Task { await onToggle(); loading = false }
            }) {
                Group {
                    if loading {
                        ProgressView().tint(Neon.cyan).scaleEffect(0.7)
                    } else {
                        Text(isFollowing ? lang.t("UNFOLLOW", "ОТПИСАТЬСЯ") : lang.t("FOLLOW", "ПОДПИСАТЬСЯ"))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(isFollowing ? .gray : Neon.cyan)
                            .tracking(1)
                    }
                }
                .frame(width: 88, height: 28)
                .background(isFollowing ? Neon.surface : Neon.cyan.opacity(0.1))
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(isFollowing ? Color.gray.opacity(0.2) : Neon.cyan.opacity(0.4), lineWidth: 1))
            }
            .disabled(loading)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Neon.surface.opacity(0.4)).cornerRadius(4)
    }
}

// MARK: - Player Profile View (other player)

struct PlayerProfileView: View {
    let player: PlayerRecord
    let myName: String
    var isFollowing: Bool
    @Environment(AppLanguage.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var following: Bool
    @State private var loading = false

    init(player: PlayerRecord, myName: String, isFollowing: Bool) {
        self.player = player; self.myName = myName; self.isFollowing = isFollowing
        _following = State(initialValue: isFollowing)
    }

    var accent: Color { Neon.colorMap[player.name.count % 5 == 0 ? "orange" :
                                      player.name.count % 5 == 1 ? "blue" :
                                      player.name.count % 5 == 2 ? "green" :
                                      player.name.count % 5 == 3 ? "red" : "purple"] ?? Neon.cyan }

    var levelData: (String, Color) {
        switch player.total_area {
        case 0..<10000:     return (lang.t("ROOKIE",    "НОВИЧОК"),    .gray)
        case 10000..<50000: return (lang.t("FIGHTER",   "БОЕЦ"),       Neon.cyan)
        case 50000..<200000:return (lang.t("WARRIOR",   "ВОИН"),       Neon.orange)
        default:            return (lang.t("CONQUEROR", "ЗАВОЕВАТЕЛЬ"),Neon.magenta)
        }
    }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()
            CornerBrackets(color: accent)

            VStack(spacing: 20) {
                // Close
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white).frame(width: 36, height: 36)
                            .background(.ultraThinMaterial).cornerRadius(4)
                    }
                }
                .padding(.horizontal).padding(.top, 16)

                // Avatar
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 100, height: 100)
                        .shadow(color: accent.opacity(0.5), radius: 20)
                    Circle().stroke(accent.opacity(0.6), lineWidth: 2).frame(width: 80, height: 80)
                    Text(String(player.name.prefix(1)).uppercased())
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundColor(accent).shadow(color: accent, radius: 8)
                }

                // Name + rank
                VStack(spacing: 6) {
                    Text(player.name.uppercased())
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text(levelData.0)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(levelData.1).tracking(4)
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(levelData.1.opacity(0.1)).cornerRadius(3)
                }

                // Follow button
                Button(action: toggleFollow) {
                    HStack(spacing: 8) {
                        if loading { ProgressView().tint(.white).scaleEffect(0.8) }
                        Text(following ? lang.t("UNFOLLOW", "ОТПИСАТЬСЯ") : lang.t("FOLLOW", "ПОДПИСАТЬСЯ"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(following ? .gray : Neon.bg).tracking(2)
                    }
                    .frame(maxWidth: 200).padding(.vertical, 12)
                    .background(following ? Neon.surface : accent)
                    .cornerRadius(4)
                    .shadow(color: following ? .clear : accent.opacity(0.5), radius: 8)
                }
                .disabled(loading)

                // Stats
                NeonDivider(color: accent).padding(.horizontal, 40)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    CyberStatCard(icon: "figure.run", label: lang.t("RUNS", "ЗАБЕГОВ"), value: "\(player.total_runs)")
                    CyberStatCard(icon: "map.fill",   label: lang.t("TERRITORY", "ТЕРРИТОРИЯ"),
                                  value: String(format: "%.0f M²", player.total_area))
                    CyberStatCard(icon: "road.lanes", label: lang.t("DISTANCE", "ДИСТАНЦИЯ"),
                                  value: String(format: "%.1f KM", player.total_distance / 1000))
                    CyberStatCard(icon: "bolt.fill",  label: lang.t("ATTACKS", "АТАК"),
                                  value: "\(player.total_attacks)", color: Neon.red)
                }
                .padding(.horizontal)
                Spacer()
            }
        }
    }

    private func toggleFollow() {
        loading = true
        Task {
            if following {
                await SupabaseService.shared.unfollowPlayer(from: myName, to: player.name)
            } else {
                await SupabaseService.shared.followPlayer(from: myName, to: player.name)
            }
            following.toggle()
            loading = false
        }
    }
}
