import Foundation
import CoreLocation

// MARK: - Supabase Service

class SupabaseService {
    static let shared = SupabaseService()

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: "\(SUPABASE_URL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SUPABASE_KEY)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }

    func saveRun(playerName: String, coordinates: [CLLocationCoordinate2D], color: String) async {
        let coords = coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
        guard let coordData = try? JSONEncoder().encode(coords),
              let coordString = String(data: coordData, encoding: .utf8),
              let bodyData = try? JSONSerialization.data(withJSONObject: ["player_name": playerName, "coordinates": coordString, "color": color, "is_active": "true"]),
              let request = makeRequest("/rest/v1/runs", method: "POST", body: bodyData) else { return }
        try? await URLSession.shared.data(for: request)
    }

    func deactivateRuns(ids: [String]) async {
        for id in ids {
            guard let bodyData = try? JSONSerialization.data(withJSONObject: ["is_active": false]),
                  let request = makeRequest("/rest/v1/runs?id=eq.\(id)", method: "PATCH", body: bodyData) else { continue }
            try? await URLSession.shared.data(for: request)
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
        guard let request = makeRequest("/rest/v1/runs?player_name=eq.\(encoded)&order=created_at.desc&limit=20") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([RunRecord].self, from: data) else { return [] }
        return records
    }

    func upsertPlayer(name: String, distance: Double, area: Double, attacks: Int) async {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let fetchRequest = makeRequest("/rest/v1/players?name=eq.\(encoded)") else { return }
        if let (data, _) = try? await URLSession.shared.data(for: fetchRequest),
           let existing = try? JSONDecoder().decode([PlayerRecord].self, from: data),
           let player = existing.first {
            let updated: [String: Any] = [
                "total_distance": player.total_distance + distance,
                "total_area": player.total_area + area,
                "total_attacks": player.total_attacks + attacks,
                "total_runs": player.total_runs + 1
            ]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: updated),
                  let request = makeRequest("/rest/v1/players?name=eq.\(encoded)", method: "PATCH", body: bodyData) else { return }
            try? await URLSession.shared.data(for: request)
        } else {
            let body: [String: Any] = ["name": name, "total_distance": distance, "total_area": area, "total_attacks": attacks, "total_runs": 1]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let request = makeRequest("/rest/v1/players", method: "POST", body: bodyData) else { return }
            try? await URLSession.shared.data(for: request)
        }
    }

    func fetchLeaderboard() async -> [PlayerRecord] {
        guard let request = makeRequest("/rest/v1/players?order=total_area.desc&limit=20") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let records = try? JSONDecoder().decode([PlayerRecord].self, from: data) else { return [] }
        return records
    }
}
