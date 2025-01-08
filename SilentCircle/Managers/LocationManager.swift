import CoreLocation
import MapKit
import Combine
import CoreData

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager: CLLocationManager
    @Published var userLocation: CLLocation?
    @Published var monitoredRegions: Set<CLCircularRegion> = []
    @Published var monitoringStatus: MonitoringStatus = .unknown
    @Published var currentGeofence: Geofence?
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private var isRequestingLocation = false
    private var statusCheckTimer: Timer?
    private var shouldSendNotifications = true
    
    enum MonitoringStatus {
        case ready
        case noGeofences
        case noLocation
        case notAuthorized
        case unknown
    }
    
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }
    
    override init() {
        self.manager = CLLocationManager()
        super.init()
        
        // Configure manager before setting delegate
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Enable background capabilities first
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
        
        // Set delegate after configuration
        manager.delegate = self
        
        // Request authorization last
        manager.requestAlwaysAuthorization()
        
        // Verify notification authorization
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 Notification Settings - Authorization Status: \(settings.authorizationStatus.rawValue)")
            if settings.authorizationStatus != .authorized {
                print("⚠️ Notifications not authorized - requesting permission")
                NotificationManager.shared.requestAuthorization()
            }
        }
        
        // Start periodic status checks
        startStatusChecks()
    }
    
    private func startStatusChecks() {
        // Remove timer-based checks since we'll rely on delegate callbacks
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
        
        // Initial status will be set through delegate callbacks
        updateMonitoringStatus()
    }
    
    private func updateMonitoringStatus() {
        // Check authorization first
        switch manager.authorizationStatus {
        case .authorizedAlways:
            // Check if we have any active geofences to monitor
            let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isActive == YES")
            
            do {
                let activeGeofences = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
                if activeGeofences.isEmpty {
                    monitoringStatus = .noGeofences
                } else {
                    monitoringStatus = .ready
                }
            } catch {
                print("❌ Error fetching active geofences: \(error)")
                monitoringStatus = .unknown
            }
            
        case .notDetermined:
            monitoringStatus = .unknown
        default:
            monitoringStatus = .notAuthorized
        }
    }
    
    func requestLocation() {
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        print("🎯 Requesting location update")
        manager.requestLocation()
        
        // Reset request flag after a timeout
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second timeout
            isRequestingLocation = false
        }
    }
    
    func startMonitoringGeofence(_ geofence: Geofence) {
        shouldSendNotifications = false  // Disable notifications during setup
        // First stop monitoring any existing region for this geofence
        stopMonitoringGeofence(geofence)
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            radius: geofence.radius,
            identifier: geofence.name ?? geofence.id?.uuidString ?? UUID().uuidString
        )
        
        manager.startMonitoring(for: region)
        monitoredRegions.insert(region)
        print("🎯 Started monitoring geofence: \(geofence.name ?? "Unknown") at (\(geofence.latitude), \(geofence.longitude))")
        
        // Remove the initial location check that was sending notifications
        // This way notifications only trigger on actual region entry/exit
        manager.requestLocation()
        // Re-enable notifications after a delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 second delay
            shouldSendNotifications = true
        }
    }
    
    func stopMonitoringGeofence(_ geofence: Geofence) {
        // Check if we were inside this geofence before stopping
        let wasInside = currentGeofence?.name == geofence.name
        
        // Remove any existing regions for this geofence
        monitoredRegions.filter { $0.identifier == geofence.name }.forEach { region in
            manager.stopMonitoring(for: region)
            monitoredRegions.remove(region)
        }
        
        // If we were inside, clear current geofence but only notify if enabled
        if wasInside {
            Task { @MainActor in
                self.currentGeofence = nil
                if shouldSendNotifications {  // Only send if enabled
                    NotificationManager.shared.scheduleNotification(
                        title: "Exiting Silent Circle (\(geofence.name ?? "Unknown"))",
                        body: "Notifications have been restored."
                    )
                }
            }
        }
        
        updateMonitoringStatus()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateMonitoringStatus()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last else { return }
        print("📍 Location update: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        
        Task { @MainActor in
            self.userLocation = userLocation
        }
        
        var foundActiveGeofence = false
        
        for region in monitoredRegions {
            guard let geofence = findGeofence(for: region) else { continue }
            
            let center = CLLocation(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            )
            
            let distance = userLocation.distance(from: center)
            print("📍 Distance to '\(geofence.name ?? "Unknown")': \(Int(distance))m (radius: \(Int(geofence.radius))m)")
            
            if distance <= geofence.radius {
                // Only notify if we weren't already in this geofence
                if self.currentGeofence?.id != geofence.id {
                    print("🎯 Entering geofence: '\(geofence.name ?? "Unknown")'")
                    if shouldSendNotifications {  // Only send if enabled
                        NotificationManager.shared.scheduleNotification(
                            title: "Entering Silent Circle (\(geofence.name ?? "Unknown"))",
                            body: "Notifications will be turned off until you leave."
                        )
                    }
                }
                self.currentGeofence = geofence
                foundActiveGeofence = true
                print("✅ Inside geofence: '\(geofence.name ?? "Unknown")'")
                break
            }
        }
        
        if !foundActiveGeofence {
            // Only notify if we were in a geofence before
            if let oldGeofence = self.currentGeofence {
                print("🚶‍♂️ Exiting geofence: '\(oldGeofence.name ?? "Unknown")'")
                if shouldSendNotifications {  // Only send if enabled
                    NotificationManager.shared.scheduleNotification(
                        title: "Exiting Silent Circle (\(oldGeofence.name ?? "Unknown"))",
                        body: "Notifications have been restored."
                    )
                }
            }
            self.currentGeofence = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let circularRegion = (region as! CLCircularRegion)
        print("🎯 Entered region: '\(circularRegion.identifier)'")
        
        // Find and set the current geofence
        if let geofence = findGeofence(for: circularRegion) {
            Task { @MainActor in
                self.currentGeofence = geofence
                print("✅ Set current geofence: '\(geofence.name ?? "Unknown")'")
            }
        }
        
        NotificationManager.shared.scheduleNotification(
            title: "Entering Silent Circle (\(circularRegion.identifier))",
            body: "Notifications will be turned off until you leave."
        )
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let circularRegion = (region as! CLCircularRegion)
        print("🚶‍♂️ Exited region: '\(circularRegion.identifier)'")
        
        Task { @MainActor in
            if self.currentGeofence?.name == circularRegion.identifier {
                print("❌ Clearing current geofence: '\(circularRegion.identifier)'")
                self.currentGeofence = nil
            }
        }
        
        NotificationManager.shared.scheduleNotification(
            title: "Exiting Silent Circle (\(circularRegion.identifier))",
            body: "Notifications have been restored."
        )
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("⚠️ Monitoring failed for region: '\(region?.identifier ?? "Unknown")', error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }
    
    private func findGeofence(for region: CLCircularRegion) -> Geofence? {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", region.identifier)
        return try? PersistenceController.shared.container.viewContext.fetch(fetchRequest).first
    }
    
    deinit {
        locationSubject.send(completion: .finished)
        statusCheckTimer?.invalidate()
    }
    
    func checkCurrentLocation() {
        manager.requestLocation()
    }
} 