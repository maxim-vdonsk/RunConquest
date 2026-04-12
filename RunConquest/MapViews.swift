import SwiftUI
import MapKit
import CoreLocation

// MARK: - Dark Map View

struct RunMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var routeCoordinates: [CLLocationCoordinate2D]
    var otherRuns: [RunRecord]
    var myColor: String
    var attackedIds: Set<String>

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        mapView.overrideUserInterfaceStyle = .dark
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        for run in otherRuns {
            guard let coords = parseCoordinates(run.coordinates), coords.count >= 3 else { continue }
            let isAttacked = attackedIds.contains(run.id ?? "")
            let buffered = makeBufferedPolygon(coords: coords, radius: 30)
            mapView.addOverlay(ColoredPolygon(coordinates: buffered, count: buffered.count, color: isAttacked ? "attacked" : run.color, playerName: run.player_name), level: .aboveRoads)
            if let center = coords.first {
                mapView.addAnnotation(PlayerAnnotation(coordinate: center, title: run.player_name, isAttacked: isAttacked))
            }
        }
        if routeCoordinates.count >= 2 {
            mapView.addOverlay(MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count))
        }
        if routeCoordinates.count >= 3 {
            let buffered = makeBufferedPolygon(coords: routeCoordinates, radius: 30)
            mapView.addOverlay(ColoredPolygon(coordinates: buffered, count: buffered.count, color: myColor, playerName: "me"), level: .aboveRoads)
        }
    }

    func makeBufferedPolygon(coords: [CLLocationCoordinate2D], radius: Double) -> [CLLocationCoordinate2D] {
        var result: [CLLocationCoordinate2D] = []
        for coord in coords {
            for i in 0..<12 {
                let angle = Double(i) * (2 * .pi / 12)
                result.append(CLLocationCoordinate2D(
                    latitude: coord.latitude + (radius / 111320) * cos(angle),
                    longitude: coord.longitude + (radius / (111320 * cos(coord.latitude * .pi / 180))) * sin(angle)
                ))
            }
        }
        return result
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? ColoredPolygon {
                let r = MKPolygonRenderer(polygon: polygon)
                let c = colorFromString(polygon.color)
                r.fillColor = c.withAlphaComponent(polygon.playerName == "me" ? 0.6 : 0.35)
                r.strokeColor = c.withAlphaComponent(0.9)
                r.lineWidth = polygon.color == "attacked" ? 3 : 2
                return r
            }
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.white.withAlphaComponent(0.9)
                r.lineWidth = 3; return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let a = annotation as? PlayerAnnotation else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "player")
            view.glyphText = a.isAttacked ? "⚔️" : "🏃"
            view.markerTintColor = a.isAttacked ? .red : .systemOrange
            view.titleVisibility = .visible
            return view
        }

        func colorFromString(_ color: String) -> UIColor {
            switch color {
            case "orange": return .orange
            case "blue": return .systemBlue
            case "green": return .systemGreen
            case "red": return .systemRed
            case "purple": return .systemPurple
            case "attacked": return .red
            default: return .orange
            }
        }
    }
}

// MARK: - Map Helpers

class ColoredPolygon: MKPolygon {
    var color: String = "orange"
    var playerName: String = ""
    convenience init(coordinates: [CLLocationCoordinate2D], count: Int, color: String, playerName: String) {
        var c = coordinates; self.init(coordinates: &c, count: count)
        self.color = color; self.playerName = playerName
    }
}

class PlayerAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let isAttacked: Bool
    init(coordinate: CLLocationCoordinate2D, title: String, isAttacked: Bool) {
        self.coordinate = coordinate; self.title = title; self.isAttacked = isAttacked
    }
}
