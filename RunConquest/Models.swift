import CoreLocation

// MARK: - Models

struct RunRecord: Codable, Identifiable {
    let id: String?
    let player_name: String
    let coordinates: String
    let color: String
    let created_at: String?
    var is_active: Bool?
}

struct PlayerRecord: Codable, Identifiable {
    let id: String?
    var name: String
    var total_distance: Double
    var total_area: Double
    var total_attacks: Int
    var total_runs: Int
    let created_at: String?
}

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
