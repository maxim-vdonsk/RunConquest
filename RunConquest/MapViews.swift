import SwiftUI
import MapKit
import CoreLocation
import MapboxMaps

// MARK: - Mapbox Map View

struct RunMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var routeCoordinates: [CLLocationCoordinate2D]
    var otherRuns: [RunRecord]
    var myColor: String
    var attackedIds: Set<String>

    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let initOptions = MapInitOptions(
            styleURI: StyleURI(rawValue: MAPBOX_STYLE)
        )
        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: initOptions)
        mapView.mapboxMap.mapboxToken = MAPBOX_TOKEN
        mapView.location.options.puckType = .puck2D(.makeDefault(showBearing: true))
        mapView.location.options.puckBearingEnabled = true
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        let camera = CameraOptions(center: region.center, zoom: 15.5)
        mapView.camera.ease(to: camera, duration: 0.5)

        context.coordinator.updateOverlays(
            mapView: mapView,
            routeCoordinates: routeCoordinates,
            otherRuns: otherRuns,
            myColor: myColor,
            attackedIds: attackedIds
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var mapView: MapboxMaps.MapView?
        var addedSourceIds: Set<String> = []
        var addedLayerIds: Set<String> = []

        func updateOverlays(mapView: MapboxMaps.MapView, routeCoordinates: [CLLocationCoordinate2D], otherRuns: [RunRecord], myColor: String, attackedIds: Set<String>) {
            let style = mapView.mapboxMap.style

            for layerId in addedLayerIds { try? style.removeLayer(withId: layerId) }
            for sourceId in addedSourceIds { try? style.removeSource(withId: sourceId) }
            addedLayerIds.removeAll()
            addedSourceIds.removeAll()

            for run in otherRuns {
                guard let coords = parseCoordinates(run.coordinates), coords.count >= 3 else { continue }
                let id = run.id ?? UUID().uuidString
                let isAttacked = attackedIds.contains(run.id ?? "")
                let colorHex = isAttacked ? "#ff0000" : colorToHex(run.color)
                addZone(style: style, id: "zone-\(id)", coords: coords, colorHex: colorHex, opacity: 0.35)
            }

            if routeCoordinates.count >= 2 {
                addRoute(style: style, id: "my-route", coords: routeCoordinates)
            }

            if routeCoordinates.count >= 3 {
                addZone(style: style, id: "my-zone", coords: routeCoordinates, colorHex: colorToHex(myColor), opacity: 0.6)
            }
        }

        func addZone(style: MapboxMaps.Style, id: String, coords: [CLLocationCoordinate2D], colorHex: String, opacity: Double) {
            let buffered = makeBufferedPolygon(coords: coords, radius: 30)
            let positions = buffered.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let polygon = Polygon([positions])

            var source = GeoJSONSource(id: id)
            source.data = .geometry(.polygon(polygon))
            try? style.addSource(source)
            addedSourceIds.insert(id)

            var fillLayer = FillLayer(id: "\(id)-fill", source: id)
            fillLayer.fillColor = .constant(StyleColor(UIColor(hex: colorHex) ?? .orange))
            fillLayer.fillOpacity = .constant(opacity)
            try? style.addLayer(fillLayer)
            addedLayerIds.insert("\(id)-fill")

            var lineLayer = LineLayer(id: "\(id)-line", source: id)
            lineLayer.lineColor = .constant(StyleColor(UIColor(hex: colorHex) ?? .orange))
            lineLayer.lineWidth = .constant(2)
            try? style.addLayer(lineLayer)
            addedLayerIds.insert("\(id)-line")
        }

        func addRoute(style: MapboxMaps.Style, id: String, coords: [CLLocationCoordinate2D]) {
            let positions = coords.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let line = LineString(positions)

            var source = GeoJSONSource(id: id)
            source.data = .geometry(.lineString(line))
            try? style.addSource(source)
            addedSourceIds.insert(id)

            var lineLayer = LineLayer(id: "\(id)-layer", source: id)
            lineLayer.lineColor = .constant(StyleColor(.white))
            lineLayer.lineWidth = .constant(3)
            lineLayer.lineCap = .constant(.round)
            lineLayer.lineJoin = .constant(.round)
            try? style.addLayer(lineLayer)
            addedLayerIds.insert("\(id)-layer")
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

        func colorToHex(_ color: String) -> String {
            switch color {
            case "orange": return "#FF8C00"
            case "blue":   return "#0080FF"
            case "green":  return "#00CC44"
            case "red":    return "#FF2200"
            case "purple": return "#9933FF"
            default:       return "#FF8C00"
            }
        }
    }
}

// MARK: - UIColor from HEX

extension UIColor {
    convenience init?(hex: String) {
        let start = hex.hasPrefix("#") ? hex.index(hex.startIndex, offsetBy: 1) : hex.startIndex
        let hexColor = String(hex[start...])
        guard hexColor.count == 6, let hexNumber = UInt64(hexColor, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((hexNumber & 0xff0000) >> 16) / 255,
            green: CGFloat((hexNumber & 0x00ff00) >> 8)  / 255,
            blue:  CGFloat( hexNumber & 0x0000ff)         / 255,
            alpha: 1
        )
    }
}
