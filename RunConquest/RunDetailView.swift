import SwiftUI
import Charts
import MapKit

// MARK: - Run Detail View

struct RunDetailView: View {
    let run: RunRecord
    let playerName: String

    @Environment(AppLanguage.self) private var lang
    @Environment(\.dismiss) private var dismiss

    @State private var splits: [RunSplit] = []
    @State private var isLoading = true
    @State private var showReplay = false

    var accent: Color { Neon.colorMap[run.color] ?? Neon.cyan }
    var coords: [CLLocationCoordinate2D] { parseCoordinates(run.coordinates) ?? [] }

    // MARK: - Body

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(accent)
                    Text(lang.t("LOADING...", "ЗАГРУЗКА..."))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(accent.opacity(0.5)).tracking(3)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {

                        // MARK: Mini Map
                        miniMap
                            .frame(height: 220)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.3), lineWidth: 1))

                        // MARK: Date + Status
                        HStack {
                            NeonLabel(text: formatDate(run.created_at ?? ""), color: accent)
                            Spacer()
                            statusBadge
                        }

                        // MARK: Metrics
                        metricsGrid

                        // MARK: Pace Chart
                        if splits.count >= 2 {
                            paceChart
                        }

                        // MARK: Splits
                        if !splits.isEmpty {
                            splitsSection
                        }

                        // MARK: Replay Button
                        if let rid = run.id {
                            Button(action: { showReplay = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill").foregroundColor(accent)
                                    Text(lang.t("[ REPLAY THIS RUN ]", "[ ПРОСМОТР МАРШРУТА ]"))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(accent).tracking(2)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(accent.opacity(0.1)).cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.5), lineWidth: 1))
                            }
                            .fullScreenCover(isPresented: $showReplay) {
                                ReplayView(coordinates: coords, color: run.color)
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                    }
                    .padding(.trailing, 16).padding(.top, 16)
                }
                Spacer()
            }
        }
        .task {
            if let rid = run.id {
                splits = await SupabaseService.shared.fetchSplits(runId: rid)
            }
            isLoading = false
        }
    }

    // MARK: - Mini Map (MKMapView snapshot)

    private var miniMap: some View {
        RunMiniMapView(coordinates: coords, color: run.color)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        let active = run.is_active == true
        return Text(active ? lang.t("ACTIVE", "АКТИВНЫЙ") : lang.t("CAPTURED", "ЗАХВАЧЕН"))
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(active ? Neon.green : .gray.opacity(0.5))
            .tracking(2)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((active ? Neon.green : Color.gray).opacity(0.1))
            .cornerRadius(3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke((active ? Neon.green : Color.gray).opacity(0.3), lineWidth: 1))
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                MetricTile(icon: "figure.run",
                           label: lang.t("DISTANCE", "ДИСТАНЦИЯ"),
                           value: String(format: "%.2f", routeDistance()),
                           unit: "KM", color: .white)
                // Use distance from route coords count estimate
                MetricTile(icon: "clock.fill",
                           label: lang.t("TIME", "ВРЕМЯ"),
                           value: run.total_time_seconds.map { formatDuration(seconds: $0) } ?? "--:--",
                           unit: "", color: .white)
            }
            HStack(spacing: 8) {
                MetricTile(icon: "speedometer",
                           label: lang.t("AVG PACE", "СР. ТЕМП"),
                           value: run.avg_pace_seconds.map { formatPace(seconds: $0) } ?? "--:--",
                           unit: lang.t("MIN/KM", "МИН/КМ"), color: accent)
                MetricTile(icon: "star.fill",
                           label: lang.t("SCORE", "ОЧКИ"),
                           value: "\(run.points ?? 0)",
                           unit: lang.t("PTS", "ОЧК"), color: accent)
            }
            if (run.avg_heart_rate ?? 0) > 0 || (run.calories ?? 0) > 0 {
                HStack(spacing: 8) {
                    if let hr = run.avg_heart_rate, hr > 0 {
                        MetricTile(icon: "heart.fill",
                                   label: lang.t("AVG BPM", "СР. ПУЛЬС"),
                                   value: "\(hr)", unit: "BPM", color: Neon.red)
                    }
                    if let cal = run.calories, cal > 0 {
                        MetricTile(icon: "flame.fill",
                                   label: lang.t("CALORIES", "КАЛОРИИ"),
                                   value: "\(cal)",
                                   unit: lang.t("KCAL", "ККАЛ"), color: Neon.orange)
                    }
                }
            }
        }
    }

    // MARK: - Pace Chart

    private var paceChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            NeonLabel(text: lang.t("> PACE CHART:", "> ТЕМП ПО КМ:"), color: accent)
            let best  = splits.min(by: { $0.pace_sec < $1.pace_sec })
            let worst = splits.max(by: { $0.pace_sec < $1.pace_sec })

            Chart(splits) { split in
                BarMark(
                    x: .value("KM", split.km_index),
                    y: .value(lang.t("Pace", "Темп"), split.pace_sec)
                )
                .foregroundStyle(
                    split.id == best?.id  ? Neon.green :
                    split.id == worst?.id ? Neon.red   : accent.opacity(0.6)
                )
                .cornerRadius(2)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisValueLabel {
                        if let s = v.as(Int.self) {
                            Text(formatPace(seconds: s))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(Color.white.opacity(0.06))
                }
            }
            .chartXAxis {
                AxisMarks { v in
                    AxisValueLabel {
                        if let km = v.as(Int.self) {
                            Text("\(km)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                }
            }
            .frame(height: 110)
        }
        .padding(12)
        .background(Neon.surface.opacity(0.4)).cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Splits Section

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                NeonLabel(text: lang.t("> SPLITS:", "> СПЛИТЫ:"), color: accent)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(accent.opacity(0.06))

            ForEach(splits) { split in
                HStack {
                    Text("\(split.km_index)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white).frame(width: 28, alignment: .leading)
                    Spacer()
                    Text(formatDuration(seconds: split.duration_sec))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6)).frame(width: 52, alignment: .trailing)
                    Text(formatPace(seconds: split.pace_sec))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(accent).frame(width: 52, alignment: .trailing)
                    if let hr = split.heart_rate {
                        Text("\(hr)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Neon.red.opacity(0.7)).frame(width: 36, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.02))
            }
        }
        .background(Neon.surface.opacity(0.4)).cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Helpers

    func routeDistance() -> Double {
        guard let coords = parseCoordinates(run.coordinates), coords.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
            let b = CLLocation(latitude: coords[i].latitude,   longitude: coords[i].longitude)
            total += a.distance(from: b)
        }
        return total / 1000
    }

    func formatDate(_ dateStr: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: dateStr) else { return dateStr }
        let d = DateFormatter()
        d.dateFormat = "dd MMM yyyy, HH:mm"
        d.locale = Locale(identifier: lang.code == "ru" ? "ru_RU" : "en_US")
        return d.string(from: date).uppercased()
    }
}

// MARK: - Mini Map (MKMapView)

struct RunMiniMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let color: String

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.overrideUserInterfaceStyle = .dark
        map.mapType = .mutedStandard
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        guard coordinates.count >= 2 else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        map.addOverlay(polyline)

        // Fit region
        var region = MKCoordinateRegion(coordinates: coordinates)
        region.span.latitudeDelta  *= 1.4
        region.span.longitudeDelta *= 1.4
        map.setRegion(region, animated: false)

        context.coordinator.color = color
        map.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        var color: String = "orange"

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                switch color {
                case "blue":   renderer.strokeColor = UIColor(red: 0, green: 0.95, blue: 1, alpha: 1)
                case "green":  renderer.strokeColor = UIColor(red: 0, green: 1, blue: 0.25, alpha: 1)
                case "red":    renderer.strokeColor = UIColor(red: 1, green: 0.18, blue: 0.33, alpha: 1)
                case "purple": renderer.strokeColor = UIColor(red: 0.75, green: 0, blue: 1, alpha: 1)
                default:       renderer.strokeColor = UIColor(red: 1, green: 0.42, blue: 0, alpha: 1)
                }
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - MKCoordinateRegion from coords

extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self.init()
            return
        }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude:  (lats.max()! + lats.min()!) / 2,
            longitude: (lons.max()! + lons.min()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.002, lats.max()! - lats.min()!),
            longitudeDelta: max(0.002, lons.max()! - lons.min()!)
        )
        self.init(center: center, span: span)
    }
}
