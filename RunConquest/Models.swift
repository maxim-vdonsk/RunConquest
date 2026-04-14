import CoreLocation

// MARK: - Run

struct RunRecord: Codable, Identifiable {
    let id: String?
    let player_name: String
    let coordinates: String
    let color: String
    let created_at: String?
    var is_active: Bool?
    // Phase 1: extended tracking
    var total_time_seconds: Int?
    var avg_pace_seconds: Int?
    var avg_heart_rate: Int?
    var max_heart_rate: Int?
    var calories: Int?
    var points: Int?
    var city: String?
}

// MARK: - Player

struct PlayerRecord: Codable, Identifiable {
    let id: String?
    var name: String
    var total_distance: Double
    var total_area: Double
    var total_attacks: Int
    var total_runs: Int
    let created_at: String?
    // Phase 1: extended
    var city: String?
    var total_points: Int?
    var device_token: String?
    var badge_ids: String?
    var squad_name: String?
    var email: String?
}

// MARK: - Auth

struct AuthUser: Decodable {
    let id: String
    let email: String?
}

// MARK: - Run Split

struct RunSplit: Codable, Identifiable {
    let id: String?
    let run_id: String
    let player_name: String
    let km_index: Int
    let duration_sec: Int
    let pace_sec: Int
    let heart_rate: Int?
    let created_at: String?
}

// MARK: - Friends

struct FriendRecord: Codable, Identifiable {
    let id: String?
    let follower_name: String
    let following_name: String
    let created_at: String?
}

// MARK: - Activity Feed

struct ActivityPost: Codable, Identifiable {
    let id: String?
    let player_name: String
    let type: String          // "run_completed" | "zone_captured" | "challenge_done"
    let run_id: String?
    var distance: Double?
    var area: Double?
    var points: Int?
    var likes_count: Int?
    let color: String?
    let message: String?
    let created_at: String?

    var isLikedByMe: Bool = false  // computed client-side

    enum CodingKeys: String, CodingKey {
        case id, player_name, type, run_id, distance, area, points, likes_count, color, message, created_at
    }
}

struct ActivityLike: Codable, Identifiable {
    let id: String?
    let post_id: String
    let player_name: String
    let created_at: String?
}

// MARK: - Squads

struct Squad: Codable, Identifiable {
    let id: String?
    var name: String
    let invite_code: String
    let owner_name: String
    var total_area: Double
    var total_runs: Int
    var member_count: Int
    var color: String
    let created_at: String?
}

struct SquadMember: Codable, Identifiable {
    let id: String?
    let squad_id: String
    let squad_name: String
    let player_name: String
    let joined_at: String?
}

// MARK: - Challenges

struct Challenge: Codable, Identifiable {
    let id: String?
    let title_en: String
    let title_ru: String
    let description_en: String?
    let description_ru: String?
    let type: String          // "distance" | "runs" | "territory" | "attacks"
    let target_value: Double
    let month: Int
    let year: Int
    let reward_badge: String?
    let created_at: String?
}

struct ChallengeProgress: Codable, Identifiable {
    let id: String?
    let challenge_id: String
    let player_name: String
    var current_value: Double
    var completed: Bool
    let completed_at: String?
    let created_at: String?
}

// MARK: - Coordinate (internal)

struct Coordinate: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - Helpers

func detectAttacks(myCoords: [CLLocationCoordinate2D], otherRuns: [RunRecord]) -> [String] {
    var attackedIds: [String] = []
    for run in otherRuns {
        guard let id = run.id, let coords = parseCoordinates(run.coordinates) else { continue }
        var overlap = false
        for myCoord in myCoords {
            for otherCoord in coords {
                if distance(myCoord, otherCoord) < 60 { overlap = true; break }
            }
            if overlap { break }
        }
        if overlap { attackedIds.append(id) }
    }
    return attackedIds
}

func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

func parseCoordinates(_ json: String) -> [CLLocationCoordinate2D]? {
    guard let data = json.data(using: .utf8),
          let coords = try? JSONDecoder().decode([Coordinate].self, from: data) else { return nil }
    return coords.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
}

// MARK: - Pace Formatting

func formatPace(seconds: Int) -> String {
    guard seconds > 0 else { return "--:--" }
    let min = seconds / 60
    let sec = seconds % 60
    return String(format: "%d:%02d", min, sec)
}

func formatDuration(seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}
