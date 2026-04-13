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
        MapboxOptions.accessToken = MAPBOX_TOKEN
        let styleURI = StyleURI(rawValue: MAPBOX_STYLE) ?? StyleURI.dark
        let initOptions = MapInitOptions(
            styleURI: styleURI
        )
        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: initOptions)
        let dotImage = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in
            let rect = CGRect(x: 2, y: 2, width: 16, height: 16)
            UIColor.cyan.setFill()
            UIBezierPath(ovalIn: rect).fill()
            UIColor.white.setStroke()
            let stroke = UIBezierPath(ovalIn: rect)
            stroke.lineWidth = 2
            stroke.stroke()
        }
        let bearingImage = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 10, y: 0))
            path.addLine(to: CGPoint(x: 18, y: 20))
            path.addLine(to: CGPoint(x: 10, y: 15))
            path.addLine(to: CGPoint(x: 2, y: 20))
            path.close()
            UIColor.cyan.setFill()
            path.fill()
        }
        let puck = Puck2DConfiguration(
            topImage: dotImage,
            bearingImage: bearingImage,
            shadowImage: nil,
            showsAccuracyRing: false
        )
        mapView.location.options.puckType = .puck2D(puck)
        mapView.location.options.puckBearingEnabled = true
        context.coordinator.mapView = mapView

        // Ждём загрузки стиля перед добавлением слоёв
        mapView.mapboxMap.onStyleLoaded.observeNext { [weak mapView] _ in
            guard let mapView else { return }
            context.coordinator.isStyleLoaded = true
            context.coordinator.applyPendingUpdate(mapView: mapView)
        }.store(in: &context.coordinator.cancelables)

        return mapView
    }

    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        let camera = CameraOptions(center: region.center, zoom: 15.5)
        mapView.camera.ease(to: camera, duration: 0.5)

        // Сохраняем последние данные и применяем только если стиль уже загружен
        context.coordinator.pendingRouteCoordinates = routeCoordinates
        context.coordinator.pendingOtherRuns = otherRuns
        context.coordinator.pendingMyColor = myColor
        context.coordinator.pendingAttackedIds = attackedIds

        if context.coordinator.isStyleLoaded {
            context.coordinator.applyPendingUpdate(mapView: mapView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var mapView: MapboxMaps.MapView?
        var addedSourceIds: Set<String> = []
        var addedLayerIds: Set<String> = []
        var isStyleLoaded = false
        var cancelables = Set<AnyCancelable>()

        // Последние данны��, ожидающие отрисовки
        var pendingRouteCoordinates: [CLLocationCoordinate2D] = []
        var pendingOtherRuns: [RunRecord] = []
        var pendingMyColor: String = "orange"
        var pendingAttackedIds: Set<String> = []

        func applyPendingUpdate(mapView: MapboxMaps.MapView) {
            updateOverlays(mapView: mapView, routeCoordinates: pendingRouteCoordinates, otherRuns: pendingOtherRuns, myColor: pendingMyColor, attackedIds: pendingAttackedIds)
        }

        func updateOverlays(mapView: MapboxMaps.MapView, routeCoordinates: [CLLocationCoordinate2D], otherRuns: [RunRecord], myColor: String, attackedIds: Set<String>) {
            for layerId in addedLayerIds { try? mapView.mapboxMap.removeLayer(withId: layerId) }
            for sourceId in addedSourceIds { try? mapView.mapboxMap.removeSource(withId: sourceId) }
            addedLayerIds.removeAll()
            addedSourceIds.removeAll()

            for run in otherRuns {
                guard let coords = parseCoordinates(run.coordinates), coords.count >= 3 else { continue }
                let id = run.id ?? UUID().uuidString
                let isAttacked = attackedIds.contains(run.id ?? "")
                let colorHex = isAttacked ? "#ff0000" : colorToHex(run.color)
                addZone(mapView: mapView, id: "zone-\(id)", coords: coords, colorHex: colorHex, opacity: 0.35)
            }

            if routeCoordinates.count >= 2 {
                addRoute(mapView: mapView, id: "my-route", coords: routeCoordinates)
            }
            if routeCoordinates.count >= 3 {
                addZone(mapView: mapView, id: "my-zone", coords: routeCoordinates, colorHex: colorToHex(myColor), opacity: 0.6)
            }
        }

        func addZone(mapView: MapboxMaps.MapView, id: String, coords: [CLLocationCoordinate2D], colorHex: String, opacity: Double) {
            let buffered = makeBufferedPolygon(coords: coords, radius: 30)
            let polygon = Polygon([buffered.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }])

            var source = GeoJSONSource(id: id)
            source.data = .geometry(.polygon(polygon))
            try? mapView.mapboxMap.addSource(source)
            addedSourceIds.insert(id)

            var fillLayer = FillLayer(id: "\(id)-fill", source: id)
            fillLayer.fillColor = .constant(StyleColor(UIColor(hex: colorHex) ?? .orange))
            fillLayer.fillOpacity = .constant(opacity)
            try? mapView.mapboxMap.addLayer(fillLayer)
            addedLayerIds.insert("\(id)-fill")

            var lineLayer = LineLayer(id: "\(id)-line", source: id)
            lineLayer.lineColor = .constant(StyleColor(UIColor(hex: colorHex) ?? .orange))
            lineLayer.lineWidth = .constant(2)
            try? mapView.mapboxMap.addLayer(lineLayer)
            addedLayerIds.insert("\(id)-line")
        }

        func addRoute(mapView: MapboxMaps.MapView, id: String, coords: [CLLocationCoordinate2D]) {
            let line = LineString(coords.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })

            var source = GeoJSONSource(id: id)
            source.data = .geometry(.lineString(line))
            try? mapView.mapboxMap.addSource(source)
            addedSourceIds.insert(id)

            var lineLayer = LineLayer(id: "\(id)-layer", source: id)
            lineLayer.lineColor = .constant(StyleColor(.white))
            lineLayer.lineWidth = .constant(3)
            lineLayer.lineCap = .constant(.round)
            lineLayer.lineJoin = .constant(.round)
            try? mapView.mapboxMap.addLayer(lineLayer)
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
            // GeoJSON требует замкнутое кольцо: первая и последняя точки должны совпадать
            if let first = result.first { result.append(first) }
            return result
        }

        func colorToHex(_ color: String) -> String {
            switch color {
            case "orange": return "#FF6B00"
            case "blue":   return "#00F2FF"
            case "green":  return "#00FF41"
            case "red":    return "#FF2D55"
            case "purple": return "#BF00FF"
            default:       return "#FF6B00"
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
