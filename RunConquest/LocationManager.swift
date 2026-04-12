import CoreLocation
import MapKit

// MARK: - Location Manager

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var isTracking = false
    @Published var distanceMeters: Double = 0
    @Published var conqueredArea: Double = 0
    @Published var currentSpeed: Double = 0
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func startTracking() {
        routeCoordinates = []; distanceMeters = 0; conqueredArea = 0; currentSpeed = 0; lastLocation = nil
        isTracking = true; manager.startUpdatingLocation()
    }

    func stopTracking() { isTracking = false; currentSpeed = 0 }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
            guard self.isTracking else { return }
            self.routeCoordinates.append(location.coordinate)
            if let last = self.lastLocation { self.distanceMeters += location.distance(from: last) }
            self.currentSpeed = max(0, location.speed) * 3.6
            self.lastLocation = location
            self.conqueredArea = Double(self.routeCoordinates.count) * 30 * 30 * .pi / 1_000_000 * 1_000_000
        }
    }
}
