import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private var isRequestingLocation = false
    
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        manager.requestLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            self.userLocation = location
            self.locationSubject.send(location)
            self.isRequestingLocation = false
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    deinit {
        locationSubject.send(completion: .finished)
    }
} 