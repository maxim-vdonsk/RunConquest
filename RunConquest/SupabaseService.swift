import Foundation
import CoreLocation

// MARK: - Supabase Service

class SupabaseService {
    static let shared = SupabaseService()

    func saveRun(playerName: String, coordinates: [CLLocationCoordinate2D], color: String) async {
        let coords = coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
        guard let coordData = try? JSONEncoder().encode(coords),
              let coordString = String(data: coordData, encoding: .utf8) else { return }
        let body = ["player_name": playerName, "coordinates": coordString, "color": color, "is_active": "true"]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/runs")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        try? await URLSession.shared.data(for: request)
    }

    func deactivateRuns(ids: [String]) async {
        for id in ids {
            var request = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/runs?id=eq.\(id)")!)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["is_active": false])
            try? await URLSession.shared.data(for: request)
        }
    }

    func fetchRuns() async -> [RunRecord] {
        var request = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/runs?is_active=eq.true&order=created_at.desc&limit=50")!)
        request.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([RunRecord].self, from: data) else { return [] }
        return records
    }

    func fetchMyRuns(playerName: String) async -> [RunRecord] {
        let encoded = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        var request = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/runs?player_name=eq.\(encoded)&order=created_at.desc&limit=20")!)
        request.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([RunRecord].self, from: data) else { return [] }
        return records
    }

    func upsertPlayer(name: String, distance: Double, area: Double, attacks: Int) async {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        var fetchReq = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/players?name=eq.\(encoded)")!)
        fetchReq.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        fetchReq.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
        if let (data, _) = try? await URLSession.shared.data(for: fetchReq),
           let existing = try? JSONDecoder().decode([PlayerRecord].self, from: data),
           let player = existing.first {
            let updated: [String: Any] = [
                "total_distance": player.total_distance + distance,
                "total_area": player.total_area + area,
                "total_attacks": player.total_attacks + attacks,
                "total_runs": player.total_runs + 1
            ]
            var req = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/players?name=eq.\(encoded)")!)
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
            req.httpBody = try? JSONSerialization.data(withJSONObject: updated)
            try? await URLSession.shared.data(for: req)
        } else {
            let body: [String: Any] = ["name": name, "total_distance": distance, "total_area": area, "total_attacks": attacks, "total_runs": 1]
            var req = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/players")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            try? await URLSession.shared.data(for: req)
        }
    }

    func fetchLeaderboard() async -> [PlayerRecord] {
        var request = URLRequest(url: URL(string: "\(SUPABASE_URL)/rest/v1/players?order=total_area.desc&limit=20")!)
        request.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([PlayerRecord].self, from: data) else { return [] }
        return records
    }
}
