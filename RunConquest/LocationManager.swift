import CoreLocation
import MapKit
import Observation

// MARK: - Split Data (client-side)

struct SplitData: Identifiable {
    let id = UUID()
    let kmIndex: Int       // 1, 2, 3 …
    let durationSec: Int   // сколько секунд занял этот км
    let paceSec: Int       // темп этого км (сек/км)
    var heartRate: Int?
}

// MARK: - Location Manager

@Observable
@MainActor
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
    )
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var isTracking = false

    // Дистанция и территория
    var distanceMeters: Double = 0
    var conqueredArea: Double = 0

    // Скорость и темп
    var currentSpeed: Double = 0          // км/ч
    var currentPaceSec: Int = 0           // текущий темп, сек/км
    var avgPaceSec: Int = 0               // средний темп, сек/км

    // Время
    var elapsedSeconds: Int = 0           // секунд с начала забега
    private var startDate: Date?
    private var elapsedTimer: Timer?

    // Сплиты
    var splits: [SplitData] = []
    private var lastSplitDistance: Double = 0  // дистанция на последнем сплите
    private var lastSplitTime: Date?

    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false   // не паузить при остановке
        manager.allowsBackgroundLocationUpdates = true       // GPS работает при заблокированном экране
        manager.showsBackgroundLocationIndicator = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func startTracking() {
        routeCoordinates = []
        distanceMeters = 0
        conqueredArea = 0
        currentSpeed = 0
        currentPaceSec = 0
        avgPaceSec = 0
        elapsedSeconds = 0
        splits = []
        lastSplitDistance = 0
        lastSplitTime = nil
        lastLocation = nil

        isTracking = true
        startDate = Date()
        lastSplitTime = Date()

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.startDate, self.isTracking else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
                self.updateAvgPace()
            }
        }
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        currentSpeed = 0
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Pace Calculations

    private func updateAvgPace() {
        guard distanceMeters > 50 else { return }
        avgPaceSec = Int(Double(elapsedSeconds) / (distanceMeters / 1000))
    }

    private func updateCurrentPace(speed: Double) {
        // speed в м/с → темп в сек/км
        guard speed > 0.5 else { currentPaceSec = 0; return }
        currentPaceSec = Int(1000.0 / speed)
    }

    private func checkSplit(currentHR: Int = 0) {
        let completedKm = Int(distanceMeters / 1000)
        let expectedSplits = completedKm  // сколько сплитов должно быть

        guard expectedSplits > splits.count,
              let splitStart = lastSplitTime else { return }

        let now = Date()
        let duration = Int(now.timeIntervalSince(splitStart))
        let pace = duration  // 1 км / duration сек

        splits.append(SplitData(
            kmIndex: splits.count + 1,
            durationSec: duration,
            paceSec: pace,
            heartRate: currentHR > 0 ? currentHR : nil
        ))
        lastSplitTime = now
        lastSplitDistance = Double(completedKm) * 1000
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            // Обновляем центр карты всегда (если сигнал приемлемый)
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy < 40 else { return }

            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            guard self.isTracking else { return }

            // Фильтр устаревших точек: после разблокировки iOS сбрасывает буфер —
            // отбрасываем точки старше 3 секунд
            guard abs(location.timestamp.timeIntervalSinceNow) < 3 else { return }

            // Фильтр точности: принимаем только сигналы лучше 20м
            guard location.horizontalAccuracy < 20 else { return }

            if let last = self.lastLocation {
                let delta = location.distance(from: last)
                let dt = location.timestamp.timeIntervalSince(last.timestamp)

                // Фильтр скорости: > 12 м/с (43 км/ч) — GPS-прыжок, игнорируем точку
                if dt > 0, delta / dt > 12 { return }

                // Засчитываем дистанцию только для реалистичных шагов
                if delta < 30 { self.distanceMeters += delta }
            }

            // Добавляем точку в маршрут только после всех проверок
            self.routeCoordinates.append(location.coordinate)

            let speedMs = max(0, location.speed)
            self.currentSpeed = speedMs * 3.6
            self.updateCurrentPace(speed: speedMs)
            self.lastLocation = location

            // Площадь территории — convex hull маршрута
            self.conqueredArea = polygonAreaM2(convexHull(self.routeCoordinates))

            self.checkSplit()
        }
    }

    // MARK: - Computed Helpers

    var formattedElapsed: String { formatDuration(seconds: elapsedSeconds) }
    var formattedPace: String    { formatPace(seconds: currentPaceSec) }
    var formattedAvgPace: String { formatPace(seconds: avgPaceSec) }
}

// MARK: - Геометрические утилиты

/// Выпуклая оболочка набора координат.
/// Алгоритм: Andrew's Monotone Chain, O(n log n).
/// Возвращает незамкнутый полигон (первая точка ≠ последней).
func convexHull(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
    guard points.count >= 3 else { return points }

    let cosLat = max(cos(points[0].latitude * .pi / 180), 1e-6)

    typealias Pt = (x: Double, y: Double, coord: CLLocationCoordinate2D)

    let proj: [Pt] = points.map {
        (x: $0.longitude * 111_320.0 * cosLat,
         y: $0.latitude  * 111_320.0,
         coord: $0)
    }
    let sorted = proj.sorted { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) }

    func cross(_ O: Pt, _ A: Pt, _ B: Pt) -> Double {
        (A.x - O.x) * (B.y - O.y) - (A.y - O.y) * (B.x - O.x)
    }

    var lower: [Pt] = []
    for p in sorted {
        while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
            lower.removeLast()
        }
        lower.append(p)
    }

    var upper: [Pt] = []
    for p in sorted.reversed() {
        while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
            upper.removeLast()
        }
        upper.append(p)
    }

    lower.removeLast()
    upper.removeLast()
    return (lower + upper).map { $0.coord }
}

/// Площадь полигона в квадратных метрах (формула Шуэлейса).
/// Принимает незамкнутый полигон.
func polygonAreaM2(_ coords: [CLLocationCoordinate2D]) -> Double {
    guard coords.count >= 3 else { return 0 }
    let cosLat = max(cos(coords[0].latitude * .pi / 180), 1e-6)
    var area = 0.0
    let n = coords.count
    for i in 0..<n {
        let j = (i + 1) % n
        let xi = coords[i].longitude * 111_320.0 * cosLat
        let yi = coords[i].latitude  * 111_320.0
        let xj = coords[j].longitude * 111_320.0 * cosLat
        let yj = coords[j].latitude  * 111_320.0
        area += xi * yj - xj * yi
    }
    return abs(area) / 2
}
