import SwiftUI

// MARK: - Feed View

struct FeedView: View {
    let playerName: String
    @Environment(AppLanguage.self) private var lang
    @State private var posts: [ActivityPost] = []
    @State private var likedIds: Set<String> = []
    @State private var isLoading = true
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// ACTIVITY FEED //", "// ЛЕНТА АКТИВНОСТИ //"))
                    Text(lang.t("FEED", "ЛЕНТА"))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(6)
                        .shadow(color: Neon.cyan, radius: 8)
                    NeonDivider().padding(.horizontal, 40)
                }
                .padding(.top, 24).padding(.bottom, 12)

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(Neon.cyan)
                        Text(lang.t("SYNCING FEED...", "ЗАГРУЗКА ЛЕНТЫ..."))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Neon.cyan.opacity(0.5)).tracking(3)
                    }
                    Spacer()
                } else if posts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40)).foregroundColor(Neon.cyan.opacity(0.3))
                        Text(lang.t("NO ACTIVITY YET", "АКТИВНОСТИ НЕТ"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.4)).tracking(2)
                        Text(lang.t("Follow players to see their runs", "Подпишись на игроков чтобы видеть их забеги"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.3))
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(posts) { post in
                                FeedPostCard(
                                    post: post,
                                    isLiked: likedIds.contains(post.id ?? ""),
                                    myName: playerName,
                                    onLike: { toggleLike(post: post) }
                                )
                            }
                        }
                        .padding(.horizontal).padding(.bottom, 24)
                    }
                    .refreshable { await loadFeed() }
                }
            }
        }
        .task { await loadFeed() }
    }

    // MARK: - Load

    private func loadFeed() async {
        isLoading = posts.isEmpty
        let following = await SupabaseService.shared.fetchFollowing(playerName: playerName)
        let names = following.map(\.following_name) + [playerName]
        let fetched = await SupabaseService.shared.fetchFeed(following: names, limit: 40)
        posts = fetched
        // Check liked
        let ids = fetched.compactMap(\.id)
        likedIds = Set(await SupabaseService.shared.fetchLikedPostIds(playerName: playerName, postIds: ids))
        isLoading = false
    }

    private func toggleLike(post: ActivityPost) {
        guard let id = post.id else { return }
        Task {
            if likedIds.contains(id) {
                likedIds.remove(id)
                await SupabaseService.shared.unlikePost(postId: id, playerName: playerName)
            } else {
                likedIds.insert(id)
                await SupabaseService.shared.likePost(postId: id, playerName: playerName)
            }
            // Update like count locally
            if let idx = posts.firstIndex(where: { $0.id == id }) {
                let delta = likedIds.contains(id) ? 1 : -1
                posts[idx].likes_count = (posts[idx].likes_count ?? 0) + delta
            }
        }
    }
}

// MARK: - Feed Post Card

struct FeedPostCard: View {
    let post: ActivityPost
    let isLiked: Bool
    let myName: String
    let onLike: () -> Void
    @Environment(AppLanguage.self) private var lang

    var accent: Color { Neon.colorMap[post.color ?? "orange"] ?? Neon.cyan }
    var isMe: Bool { post.player_name == myName }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: avatar + name + time
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(accent.opacity(0.15)).frame(width: 36, height: 36)
                    Circle().stroke(accent.opacity(0.4), lineWidth: 1).frame(width: 36, height: 36)
                    Text(String(post.player_name.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(post.player_name.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(isMe ? accent : .white)
                        if isMe {
                            Text(lang.t("YOU", "ВЫ"))
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(accent.opacity(0.6))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(accent.opacity(0.1)).cornerRadius(2)
                        }
                    }
                    Text(relativeTime(post.created_at ?? ""))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.4))
                }
                Spacer()
                typeIcon
            }

            NeonDivider(color: accent.opacity(0.3)).padding(.horizontal, -12)

            // Stats row
            HStack(spacing: 0) {
                feedStat(icon: "figure.run",
                         value: String(format: "%.2f", (post.distance ?? 0) / 1000),
                         unit: "KM")
                feedDivider
                feedStat(icon: "map.fill",
                         value: String(format: "%.0f", post.area ?? 0),
                         unit: "M²")
                feedDivider
                feedStat(icon: "star.fill",
                         value: "\(post.points ?? 0)",
                         unit: lang.t("PTS", "ОЧК"))
            }

            // Like row
            HStack {
                Button(action: onLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isLiked ? Neon.red : .gray.opacity(0.5))
                            .shadow(color: isLiked ? Neon.red.opacity(0.5) : .clear, radius: 4)
                        Text("\(post.likes_count ?? 0)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Neon.surface.opacity(0.6))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.12), lineWidth: 1))
    }

    private var typeIcon: some View {
        let (icon, color): (String, Color) = {
            switch post.type {
            case "zone_captured":    return ("bolt.fill", Neon.red)
            case "challenge_done":   return ("trophy.fill", Neon.orange)
            default:                 return ("figure.run", Neon.green)
            }
        }()
        return Image(systemName: icon).font(.system(size: 14))
            .foregroundColor(color).shadow(color: color.opacity(0.6), radius: 4)
    }

    private func feedStat(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(accent.opacity(0.6))
            Text(value).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
            Text(unit).font(.system(size: 7, design: .monospaced)).foregroundColor(.gray.opacity(0.4)).tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var feedDivider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 36)
    }

    private func relativeTime(_ dateStr: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: dateStr) else { return dateStr }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return lang.t("just now", "только что") }
        if diff < 3600 { return "\(diff/60) \(lang.t("min ago", "мин. назад"))" }
        if diff < 86400 { return "\(diff/3600) \(lang.t("hr ago", "ч. назад"))" }
        return "\(diff/86400) \(lang.t("d ago", "дн. назад"))"
    }
}
