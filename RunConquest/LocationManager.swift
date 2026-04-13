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
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            guard self.isTracking else { return }

            self.routeCoordinates.append(location.coordinate)

            if let last = self.lastLocation {
                let delta = location.distance(from: last)
                if delta < 50 {  // фильтр GPS-прыжков
                    self.distanceMeters += delta
                }
            }

            let speedMs = max(0, location.speed)
            self.currentSpeed = speedMs * 3.6
            self.updateCurrentPace(speed: speedMs)
            self.lastLocation = location

            // Площадь территории
            self.conqueredArea = Double(self.routeCoordinates.count) * 30 * 30 * .pi / 1_000_000 * 1_000_000

            self.checkSplit()
        }
    }

    // MARK: - Computed Helpers

    var formattedElapsed: String { formatDuration(seconds: elapsedSeconds) }
    var formattedPace: String    { formatPace(seconds: currentPaceSec) }
    var formattedAvgPace: String { formatPace(seconds: avgPaceSec) }
}
