import Foundation
import CoreLocation

// MARK: - Supabase Service

class SupabaseService {
    static let shared = SupabaseService()

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: SUPABASE_URL + path) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
        if method == "POST" || method == "PUT" || method == "PATCH" {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body
        return request
    }

    // MARK: - Runs

    func saveRun(playerName: String, coordinates: [CLLocationCoordinate2D], color: String,
                 totalTime: Int = 0, avgPace: Int = 0, avgHR: Int = 0, maxHR: Int = 0,
                 calories: Int = 0, points: Int = 0, city: String = "") async -> String? {
        let coords = coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
        guard let coordData = try? JSONEncoder().encode(coords),
              let coordString = String(data: coordData, encoding: .utf8) else { return nil }
        var body: [String: Any] = [
            "player_name": playerName,
            "coordinates": coordString,
            "color": color,
            "is_active": true,
            "points": points
        ]
        if totalTime > 0 { body["total_time_seconds"] = totalTime }
        if avgPace > 0   { body["avg_pace_seconds"] = avgPace }
        if avgHR > 0     { body["avg_heart_rate"] = avgHR }
        if maxHR > 0     { body["max_heart_rate"] = maxHR }
        if calories > 0  { body["calories"] = calories }
        if !city.isEmpty { body["city"] = city }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let request = makeRequest("/rest/v1/runs", method: "POST", body: bodyData) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([RunRecord].self, from: data),
              let id = records.first?.id else { return nil }
        return id
    }

    func deactivateRuns(ids: [String]) async {
        for id in ids {
            guard let bodyData = try? JSONSerialization.data(withJSONObject: ["is_active": false]),
                  let request = makeRequest("/rest/v1/runs?id=eq.\(id)", method: "PATCH", body: bodyData) else { continue }
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    func fetchRuns() async -> [RunRecord] {
        guard let request = makeRequest("/rest/v1/runs?is_active=eq.true&order=created_at.desc&limit=50") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([RunRecord].self, from: data) else { return [] }
        return records
    }

    func fetchMyRuns(playerName: String) async -> [RunRecord] {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let request = makeRequest("/rest/v1/runs?player_name=eq.\(encoded)&order=created_at.desc&limit=30") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([RunRecord].self, from: data) else { return [] }
        return records
    }

    // MARK: - Splits

    func saveSplits(_ splits: [RunSplit]) async {
        for split in splits {
            let body: [String: Any] = [
                "run_id": split.run_id,
                "player_name": split.player_name,
                "km_index": split.km_index,
                "duration_sec": split.duration_sec,
                "pace_sec": split.pace_sec,
                "heart_rate": split.heart_rate ?? 0
            ]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let request = makeRequest("/rest/v1/run_splits", method: "POST", body: bodyData) else { continue }
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    func fetchSplits(runId: String) async -> [RunSplit] {
        guard let request = makeRequest("/rest/v1/run_splits?run_id=eq.\(runId)&order=km_index.asc") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([RunSplit].self, from: data) else { return [] }
        return records
    }

    // MARK: - Players

    func upsertPlayer(name: String, distance: Double, area: Double, attacks: Int,
                      points: Int = 0, city: String = "") async {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let fetchRequest = makeRequest("/rest/v1/players?name=eq.\(encoded)") else { return }
        if let (data, _) = try? await URLSession.shared.data(for: fetchRequest),
           let existing = try? JSONDecoder().decode([PlayerRecord].self, from: data),
           let player = existing.first {
            var updated: [String: Any] = [
                "total_distance": player.total_distance + distance,
                "total_area":     player.total_area + area,
                "total_attacks":  player.total_attacks + attacks,
                "total_runs":     player.total_runs + 1,
                "total_points":   (player.total_points ?? 0) + points
            ]
            if !city.isEmpty { updated["city"] = city }
            guard let bodyData = try? JSONSerialization.data(withJSONObject: updated),
                  let request = makeRequest("/rest/v1/players?name=eq.\(encoded)", method: "PATCH", body: bodyData) else { return }
            _ = try? await URLSession.shared.data(for: request)
        } else {
            var body: [String: Any] = [
                "name": name, "total_distance": distance, "total_area": area,
                "total_attacks": attacks, "total_runs": 1, "total_points": points
            ]
            if !city.isEmpty { body["city"] = city }
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let request = makeRequest("/rest/v1/players", method: "POST", body: bodyData) else { return }
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    func updateDeviceToken(playerName: String, token: String) async {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let bodyData = try? JSONSerialization.data(withJSONObject: ["device_token": token]),
              let request = makeRequest("/rest/v1/players?name=eq.\(encoded)", method: "PATCH", body: bodyData) else { return }
        _ = try? await URLSession.shared.data(for: request)
    }

    func fetchPlayer(name: String) async -> PlayerRecord? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let request = makeRequest("/rest/v1/players?name=eq.\(encoded)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([PlayerRecord].self, from: data) else { return nil }
        return records.first
    }

    func searchPlayers(query: String) async -> [PlayerRecord] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let request = makeRequest("/rest/v1/players?name=ilike.*\(encoded)*&limit=20") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([PlayerRecord].self, from: data) else { return [] }
        return records
    }

    // MARK: - Leaderboard

    func fetchLeaderboard() async -> [PlayerRecord] {
        guard let request = makeRequest("/rest/v1/players?order=total_area.desc&limit=50") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([PlayerRecord].self, from: data) else { return [] }
        return records
    }

    func fetchLeaderboardByCity(city: String) async -> [PlayerRecord] {
        let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        guard let request = makeRequest("/rest/v1/players?city=eq.\(encoded)&order=total_area.desc&limit=50") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([PlayerRecord].self, from: data) else { return [] }
        return records
    }

    func fetchLeaderboardFriends(myName: String) async -> [PlayerRecord] {
        let following = await fetchFollowing(playerName: myName).map { $0.following_name }
        guard !following.isEmpty else { return [] }
        let names = following.map { "\"\($0)\"" }.joined(separator: ",")
        guard let request = makeRequest("/rest/v1/players?name=in.(\(names))&order=total_area.desc") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([PlayerRecord].self, from: data) else { return [] }
        return records
    }

    // MARK: - Friends

    func followPlayer(from myName: String, to targetName: String) async {
        let body = ["follower_name": myName, "following_name": targetName]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let request = makeRequest("/rest/v1/friends", method: "POST", body: bodyData) else { return }
        _ = try? await URLSession.shared.data(for: request)
    }

    func unfollowPlayer(from myName: String, to targetName: String) async {
        let f = myName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? myName
        let t = targetName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetName
        guard let request = makeRequest("/rest/v1/friends?follower_name=eq.\(f)&following_name=eq.\(t)", method: "DELETE") else { return }
        _ = try? await URLSession.shared.data(for: request)
    }

    func isFollowing(myName: String, targetName: String) async -> Bool {
        let f = myName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? myName
        let t = targetName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetName
        guard let request = makeRequest("/rest/v1/friends?follower_name=eq.\(f)&following_name=eq.\(t)") else { return false }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([FriendRecord].self, from: data) else { return false }
        return !records.isEmpty
    }

    func fetchFollowing(playerName: String) async -> [FriendRecord] {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let request = makeRequest("/rest/v1/friends?follower_name=eq.\(encoded)&order=created_at.desc") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([FriendRecord].self, from: data) else { return [] }
        return records
    }

    func fetchFollowers(playerName: String) async -> [FriendRecord] {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let request = makeRequest("/rest/v1/friends?following_name=eq.\(encoded)&order=created_at.desc") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([FriendRecord].self, from: data) else { return [] }
        return records
    }

    // MARK: - Activity Feed

    func postRunActivity(playerName: String, runId: String, distance: Double, area: Double, points: Int, color: String) async {
        let body: [String: Any] = [
            "player_name": playerName,
            "type": "run_completed",
            "run_id": runId,
            "distance": distance,
            "area": area,
            "points": points,
            "color": color
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let request = makeRequest("/rest/v1/activity_feed", method: "POST", body: bodyData) else { return }
        _ = try? await URLSession.shared.data(for: request)
    }

    func fetchFeed(following: [String], limit: Int = 30) async -> [ActivityPost] {
        guard !following.isEmpty else { return [] }
        let names = following.map { "\"\($0)\"" }.joined(separator: ",")
        guard let request = makeRequest("/rest/v1/activity_feed?player_name=in.(\(names))&order=created_at.desc&limit=\(limit)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([ActivityPost].self, from: data) else { return [] }
        return records
    }

    func fetchMyFeed(playerName: String, limit: Int = 30) async -> [ActivityPost] {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let request = makeRequest("/rest/v1/activity_feed?player_name=eq.\(encoded)&order=created_at.desc&limit=\(limit)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([ActivityPost].self, from: data) else { return [] }
        return records
    }

    func likePost(postId: String, playerName: String) async {
        let body = ["post_id": postId, "player_name": playerName]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let request = makeRequest("/rest/v1/activity_likes", method: "POST", body: bodyData) else { return }
        _ = try? await URLSession.shared.data(for: request)
        // Increment likes_count
        guard let incRequest = makeRequest("/rest/v1/activity_feed?id=eq.\(postId)", method: "PATCH",
                                           body: try? JSONSerialization.data(withJSONObject: ["likes_count": "likes_count + 1"])) else { return }
        _ = try? await URLSession.shared.data(for: incRequest)
    }

    func unlikePost(postId: String, playerName: String) async {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let request = makeRequest("/rest/v1/activity_likes?post_id=eq.\(postId)&player_name=eq.\(encoded)", method: "DELETE") else { return }
        _ = try? await URLSession.shared.data(for: request)
    }

    func fetchLikedPostIds(playerName: String, postIds: [String]) async -> [String] {
        guard !postIds.isEmpty else { return [] }
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        let ids = postIds.map { "\"\($0)\"" }.joined(separator: ",")
        guard let request = makeRequest("/rest/v1/activity_likes?player_name=eq.\(encoded)&post_id=in.(\(ids))") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([ActivityLike].self, from: data) else { return [] }
        return records.map { $0.post_id }
    }

    // MARK: - Squads

    func fetchSquads() async -> [Squad] {
        guard let request = makeRequest("/rest/v1/squads?order=total_area.desc&limit=50") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([Squad].self, from: data) else { return [] }
        return records
    }

    func fetchSquadByCode(_ code: String) async -> Squad? {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        guard let request = makeRequest("/rest/v1/squads?invite_code=eq.\(encoded)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([Squad].self, from: data) else { return nil }
        return records.first
    }

    func createSquad(name: String, ownerName: String, color: String) async -> Squad? {
        let code = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        let body: [String: Any] = ["name": name, "invite_code": code, "owner_name": ownerName, "color": color]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let request = makeRequest("/rest/v1/squads", method: "POST", body: bodyData) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([Squad].self, from: data) else { return nil }
        return records.first
    }

    func joinSquad(squadId: String, squadName: String, playerName: String) async {
        let body = ["squad_id": squadId, "squad_name": squadName, "player_name": playerName]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let request = makeRequest("/rest/v1/squad_members", method: "POST", body: bodyData) else { return }
        _ = try? await URLSession.shared.data(for: request)
        // Update squad member_count
        guard let squad = await fetchSquadByCode("") else { return }
        _ = squad
    }

    func leaveSquad(playerName: String) async {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let request = makeRequest("/rest/v1/squad_members?player_name=eq.\(encoded)", method: "DELETE") else { return }
        _ = try? await URLSession.shared.data(for: request)
        // Clear squad_name from player
        guard let bodyData = try? JSONSerialization.data(withJSONObject: ["squad_name": NSNull()]),
              let updateRequest = makeRequest("/rest/v1/players?name=eq.\(encoded)", method: "PATCH", body: bodyData) else { return }
        _ = try? await URLSession.shared.data(for: updateRequest)
    }

    func fetchMySquad(playerName: String) async -> Squad? {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let memberRequest = makeRequest("/rest/v1/squad_members?player_name=eq.\(encoded)") else { return nil }
        guard let (memberData, _) = try? await URLSession.shared.data(for: memberRequest),
              let members = try? JSONDecoder().decode([SquadMember].self, from: memberData),
              let member = members.first else { return nil }
        guard let request = makeRequest("/rest/v1/squads?id=eq.\(member.squad_id)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let squads = try? JSONDecoder().decode([Squad].self, from: data) else { return nil }
        return squads.first
    }

    func fetchSquadMembers(squadId: String) async -> [SquadMember] {
        guard let request = makeRequest("/rest/v1/squad_members?squad_id=eq.\(squadId)&order=joined_at.asc") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([SquadMember].self, from: data) else { return [] }
        return records
    }

    // MARK: - Challenges

    func fetchChallenges(month: Int, year: Int) async -> [Challenge] {
        guard let request = makeRequest("/rest/v1/challenges?month=eq.\(month)&year=eq.\(year)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([Challenge].self, from: data) else { return [] }
        return records
    }

    func fetchChallengeProgress(playerName: String) async -> [ChallengeProgress] {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        guard let request = makeRequest("/rest/v1/challenge_progress?player_name=eq.\(encoded)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([ChallengeProgress].self, from: data) else { return [] }
        return records
    }

    func upsertChallengeProgress(challengeId: String, playerName: String, value: Double, completed: Bool) async {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        let cId = challengeId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? challengeId
        // Try fetch existing
        guard let fetchReq = makeRequest("/rest/v1/challenge_progress?challenge_id=eq.\(cId)&player_name=eq.\(encoded)") else { return }
        if let (data, _) = try? await URLSession.shared.data(for: fetchReq),
           let existing = try? JSONDecoder().decode([ChallengeProgress].self, from: data),
           !existing.isEmpty {
            var body: [String: Any] = ["current_value": value, "completed": completed]
            if completed { body["completed_at"] = ISO8601DateFormatter().string(from: Date()) }
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let req = makeRequest("/rest/v1/challenge_progress?challenge_id=eq.\(cId)&player_name=eq.\(encoded)", method: "PATCH", body: bodyData) else { return }
            _ = try? await URLSession.shared.data(for: req)
        } else {
            var body: [String: Any] = ["challenge_id": challengeId, "player_name": playerName, "current_value": value, "completed": completed]
            if completed { body["completed_at"] = ISO8601DateFormatter().string(from: Date()) }
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let req = makeRequest("/rest/v1/challenge_progress", method: "POST", body: bodyData) else { return }
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}
