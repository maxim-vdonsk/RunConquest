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

        // Подписываемся на каждую загрузку стиля (observe, не observeNext),
        // чтобы слои восстанавливались после memory-pressure / переключения табов
        mapView.mapboxMap.onStyleLoaded.observe { [weak mapView, weak coord = context.coordinator] _ in
            guard let mapView, let coord else { return }
            coord.isStyleLoaded = true
            coord.applyPendingUpdate(mapView: mapView)
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
            let routeDistanceM = totalDistance(routeCoordinates)
            if routeCoordinates.count >= 3 && routeDistanceM >= 50 {
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

        func totalDistance(_ coords: [CLLocationCoordinate2D]) -> Double {
            guard coords.count > 1 else { return 0 }
            var total = 0.0
            for i in 1..<coords.count {
                let a = CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
                let b = CLLocation(latitude: coords[i].latitude,   longitude: coords[i].longitude)
                total += a.distance(from: b)
            }
            return total
        }

        // Строит коридор (ribbon) шириной radius вдоль маршрута.
        // Левая сторона → правая сторона в обратном порядке → замкнутое кольцо.
        func makeBufferedPolygon(coords: [CLLocationCoordinate2D], radius: Double) -> [CLLocationCoordinate2D] {
            guard coords.count >= 2 else {
                guard let c = coords.first else { return [] }
                return makeCircle(center: c, radius: radius)
            }

            var left:  [CLLocationCoordinate2D] = []
            var right: [CLLocationCoordinate2D] = []

            for i in 0..<coords.count {
                let c = coords[i]
                let cosLat = max(cos(c.latitude * .pi / 180.0), 1e-6)

                // Направление: от предыдущей точки к следующей (на краях — ближайший сегмент)
                let prev = coords[max(0, i - 1)]
                let next = coords[min(coords.count - 1, i + 1)]

                // Вектор направления в метрах
                let dLonM = (next.longitude - prev.longitude) * 111320.0 * cosLat
                let dLatM = (next.latitude  - prev.latitude)  * 111320.0
                let len   = sqrt(dLonM * dLonM + dLatM * dLatM)
                guard len > 0.5 else { continue }

                // Левый перпендикуляр (поворот CCW 90°): (-dLatM, dLonM)
                let latOff = ( dLonM / len * radius) / 111320.0
                let lonOff = (-dLatM / len * radius) / (111320.0 * cosLat)

                left.append(CLLocationCoordinate2D(latitude: c.latitude + latOff, longitude: c.longitude + lonOff))
                right.append(CLLocationCoordinate2D(latitude: c.latitude - latOff, longitude: c.longitude - lonOff))
            }

            guard !left.isEmpty else { return [] }

            var result = left
            result.append(contentsOf: right.reversed())
            if let first = result.first { result.append(first) }
            return result
        }

        // Вспомогательная функция: круг вокруг одной точки
        func makeCircle(center: CLLocationCoordinate2D, radius: Double) -> [CLLocationCoordinate2D] {
            let cosLat = max(cos(center.latitude * .pi / 180.0), 1e-6)
            var pts: [CLLocationCoordinate2D] = []
            for i in 0..<16 {
                let a = Double(i) * (2 * .pi / 16.0)
                pts.append(CLLocationCoordinate2D(
                    latitude:  center.latitude  + cos(a) * radius / 111320.0,
                    longitude: center.longitude + sin(a) * radius / (111320.0 * cosLat)
                ))
            }
            if let first = pts.first { pts.append(first) }
            return pts
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
