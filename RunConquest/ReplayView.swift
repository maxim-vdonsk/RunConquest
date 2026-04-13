import SwiftUI
import MapboxMaps
import CoreLocation

// MARK: - Replay View

struct ReplayView: View {
    let coordinates: [CLLocationCoordinate2D]
    let color: String

    @Environment(AppLanguage.self) private var lang
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var isPlaying = false
    @State private var playedIndex = 0
    @State private var speed: Double = 2        // точек в секунд
    @State private var timer: Timer? = nil
    @State private var progress: Double = 0

    var accent: Color { Neon.colorMap[color] ?? Neon.cyan }
    var speedLabel: String { speed == 1 ? "x1" : speed == 2 ? "x2" : "x4" }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(accent)
                    Text(lang.t("LOADING REPLAY...", "ЗАГРУЗКА ПОВТОРА..."))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(accent.opacity(0.5)).tracking(3)
                }
            } else if coordinates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 40)).foregroundColor(accent.opacity(0.4))
                    Text(lang.t("NO DATA", "НЕТ ДАННЫХ"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5)).tracking(3)
                }
            } else {
                // Map
                ReplayMapView(
                    coordinates: coordinates,
                    playedIndex: playedIndex,
                    color: color
                )
                .ignoresSafeArea()

                // Overlay
                VStack {
                    // Top bar
                    HStack {
                        Button(action: { stopReplay(); dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }

                        Spacer()

                        VStack(spacing: 2) {
                            Text(lang.t("REPLAY", "ПОВТОР"))
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(accent).tracking(4)
                                .shadow(color: accent, radius: 6)
                            Text("\(playedIndex) / \(coordinates.count) \(lang.t("pts", "тч."))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                        }

                        Spacer()

                        // Speed button
                        Button(action: cycleSpeed) {
                            Text(speedLabel)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(accent)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.4), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal).padding(.top, 8)

                    Spacer()

                    // Progress + controls
                    VStack(spacing: 12) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Neon.surface).frame(height: 3).cornerRadius(2)
                                Rectangle()
                                    .fill(accent)
                                    .frame(width: geo.size.width * progress, height: 3)
                                    .cornerRadius(2)
                                    .shadow(color: accent.opacity(0.6), radius: 4)
                                    .animation(.linear(duration: 0.1), value: progress)
                            }
                        }
                        .frame(height: 3)

                        // Play/Pause + Reset
                        HStack(spacing: 20) {
                            // Reset
                            Button(action: resetReplay) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            // Play/Pause
                            Button(action: togglePlay) {
                                ZStack {
                                    Circle().fill(accent).frame(width: 56, height: 56)
                                        .shadow(color: accent.opacity(0.6), radius: 10)
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Neon.bg)
                                }
                            }

                            // Speed
                            Button(action: cycleSpeed) {
                                Text(speedLabel)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 36)
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 40)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .background(Neon.bg.opacity(0.6))
                }

                CornerBrackets(color: accent)
            }
        }
        .onAppear {
            if !coordinates.isEmpty { startReplay() }
        }
        .onDisappear { stopReplay() }
    }

    // MARK: - Controls

    private func startReplay() {
        isPlaying = true
        scheduleTimer()
    }

    private func togglePlay() {
        if isPlaying {
            timer?.invalidate(); timer = nil
            isPlaying = false
        } else {
            if playedIndex >= coordinates.count { resetReplay(); return }
            isPlaying = true
            scheduleTimer()
        }
    }

    private func resetReplay() {
        stopReplay()
        playedIndex = 0
        progress = 0
        isPlaying = true
        scheduleTimer()
    }

    private func stopReplay() {
        timer?.invalidate(); timer = nil
        isPlaying = false
    }

    private func scheduleTimer() {
        let interval = 1.0 / (speed * 8)  // точек в интервал
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                guard self.playedIndex < self.coordinates.count else {
                    self.stopReplay(); return
                }
                self.playedIndex += 1
                self.progress = Double(self.playedIndex) / Double(self.coordinates.count)
            }
        }
    }

    private func cycleSpeed() {
        let wasPlaying = isPlaying
        stopReplay()
        speed = speed == 1 ? 2 : speed == 2 ? 4 : 1
        if wasPlaying { isPlaying = true; scheduleTimer() }
    }
}

// MARK: - Replay Map (Mapbox)

struct ReplayMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let playedIndex: Int
    let color: String

    func makeUIView(context: Context) -> MapboxMaps.MapView {
        MapboxOptions.accessToken = MAPBOX_TOKEN
        let styleURI = StyleURI(rawValue: MAPBOX_STYLE) ?? StyleURI.dark
        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: styleURI))
        mapView.location.options.puckType = nil
        context.coordinator.mapView = mapView

        mapView.mapboxMap.onStyleLoaded.observeNext { [weak mapView] _ in
            guard let mapView else { return }
            context.coordinator.isReady = true
            context.coordinator.update(mapView: mapView, coordinates: [], playedIndex: 0, colorHex: "#00F2FF")
        }.store(in: &context.coordinator.cancelables)

        return mapView
    }

    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        guard context.coordinator.isReady, playedIndex > 0 else { return }
        let slice = Array(coordinates.prefix(playedIndex))
        let hexColor: String
        switch color {
        case "blue":   hexColor = "#00F2FF"
        case "green":  hexColor = "#00FF41"
        case "red":    hexColor = "#FF2D55"
        case "purple": hexColor = "#BF00FF"
        default:       hexColor = "#FF6B00"
        }
        context.coordinator.update(mapView: mapView, coordinates: slice, playedIndex: playedIndex, colorHex: hexColor)

        // Follow last point
        if let last = slice.last {
            let camera = CameraOptions(center: last, zoom: 15.5)
            mapView.camera.ease(to: camera, duration: 0.15)
        }
    }

    func makeCoordinator() -> ReplayCoordinator { ReplayCoordinator() }

    class ReplayCoordinator: NSObject {
        var mapView: MapboxMaps.MapView?
        var isReady = false
        var cancelables = Set<AnyCancelable>()

        func update(mapView: MapboxMaps.MapView, coordinates: [CLLocationCoordinate2D], playedIndex: Int, colorHex: String) {
            ["replay-route-layer", "replay-zone-layer", "replay-dot-layer"].forEach {
                try? mapView.mapboxMap.removeLayer(withId: $0)
            }
            ["replay-route", "replay-zone", "replay-dot"].forEach {
                try? mapView.mapboxMap.removeSource(withId: $0)
            }

            guard coordinates.count >= 2 else { return }

            // Route line
            let line = LineString(coordinates.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
            var routeSource = GeoJSONSource(id: "replay-route")
            routeSource.data = .geometry(.lineString(line))
            try? mapView.mapboxMap.addSource(routeSource)
            var routeLayer = LineLayer(id: "replay-route-layer", source: "replay-route")
            routeLayer.lineColor = .constant(StyleColor(UIColor(hex: colorHex) ?? .orange))
            routeLayer.lineWidth = .constant(3)
            routeLayer.lineCap = .constant(.round)
            try? mapView.mapboxMap.addLayer(routeLayer)

            // Moving dot at last point
            if let last = coordinates.last {
                let point = Point(LocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
                var dotSource = GeoJSONSource(id: "replay-dot")
                dotSource.data = .geometry(.point(point))
                try? mapView.mapboxMap.addSource(dotSource)
                var dotLayer = CircleLayer(id: "replay-dot-layer", source: "replay-dot")
                dotLayer.circleRadius = .constant(8)
                dotLayer.circleColor = .constant(StyleColor(UIColor(hex: colorHex) ?? .white))
                dotLayer.circleStrokeWidth = .constant(2)
                dotLayer.circleStrokeColor = .constant(StyleColor(.white))
                try? mapView.mapboxMap.addLayer(dotLayer)
            }
        }
    }
}
