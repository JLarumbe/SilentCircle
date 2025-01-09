import CoreLocation
import MapKit
import Combine
import CoreData

// MARK: - Supporting Types
private enum LocationUpdateSource {
    case standard
    case regionEntry(CLRegion)
    case regionExit(CLRegion)
}

private enum GeofenceNotificationType {
    case entry
    case exit
    
    func notificationContent(for geofence: Geofence) -> (title: String, message: String) {
        switch self {
        case .entry:
            return (
                "Entering Silent Circle (\(geofence.name ?? "Unknown"))",
                "Notifications will be turned off until you leave."
            )
        case .exit:
            return (
                "Exiting Silent Circle (\(geofence.name ?? "Unknown"))",
                "Notifications have been restored."
            )
        }
    }
}

private enum GeofenceLookupMethod {
    case byName(String)
    case byRegion(CLCircularRegion)
    case byId(UUID)
}

private struct GeofenceState {
    var monitoredRegions: Set<CLCircularRegion> = []
    var lastLocationUpdate: Date?
    var shouldSendNotifications = true
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    let manager: CLLocationManager
    private let viewContext: NSManagedObjectContext
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let minimumLocationUpdateInterval: TimeInterval = 1.0
    private var state = GeofenceState()
    
    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var monitoringStatus: MonitoringStatus = .unknown
    @Published private(set) var currentGeofence: Geofence?
    
    // MARK: - Public Interface
    enum MonitoringStatus {
        case ready, noGeofences, noLocation, notAuthorized, unknown
    }
    
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }
    
    // MARK: - Initialization
    override init() {
        self.manager = CLLocationManager()
        self.viewContext = PersistenceController.shared.container.viewContext
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        print("🔧 DEBUG: Setting up location manager")
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.delegate = self
        
        // Start continuous location updates
        manager.startUpdatingLocation()
        print("📍 DEBUG: Started continuous location updates")
        
        manager.requestAlwaysAuthorization()
        
        Task {
            await checkNotificationSettings()
            updateMonitoringStatus()
        }
    }
    
    // MARK: - Location Handling
    private func handleLocationUpdate(_ location: CLLocation, source: LocationUpdateSource) async {
        let now = Date()
        
        // Check update interval
        if let lastUpdate = state.lastLocationUpdate,
           now.timeIntervalSince(lastUpdate) < minimumLocationUpdateInterval {
            return
        }
        
        // Update state
        state.lastLocationUpdate = now
        userLocation = location
        
        // Process based on source
        switch source {
        case .standard:
            await processStandardLocationUpdate(location)
        case .regionEntry(let region):
            await processRegionEntry(region, at: location)
        case .regionExit(let region):
            await processRegionExit(region, at: location)
        }
        
        // Publish location update
        locationSubject.send(location)
    }
    
    private func processStandardLocationUpdate(_ location: CLLocation) async {
        print("\n🔍 DEBUG: Processing standard location update")
        
        // Always update monitoring status when processing location
        await updateMonitoringStatus()
        
        guard !state.monitoredRegions.isEmpty else {
            print("⚠️ DEBUG: No monitored regions found")
            return
        }
        print("📍 DEBUG: Number of monitored regions: \(state.monitoredRegions.count)")
        
        var foundActiveGeofence = false
        for region in state.monitoredRegions {
            guard let geofence = findGeofence(by: .byRegion(region)) else {
                print("⚠️ DEBUG: Could not find geofence for region: \(region.identifier)")
                continue
            }
            
            let center = CLLocation(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            )
            
            let distance = location.distance(from: center)
            print("📍 DEBUG: Distance to '\(geofence.name ?? "Unknown")': \(Int(distance))m (radius: \(Int(geofence.radius))m)")
            
            if distance <= geofence.radius {
                print("✅ DEBUG: User is inside geofence '\(geofence.name ?? "Unknown")'")
                updateCurrentGeofence(geofence)
                foundActiveGeofence = true
                break
            } else {
                print("❌ DEBUG: User is outside geofence '\(geofence.name ?? "Unknown")'")
            }
        }
        
        if !foundActiveGeofence && currentGeofence != nil {
            print("🚫 DEBUG: No active geofence found at current location, clearing current geofence")
            updateCurrentGeofence(nil)
        }
    }
    
    private func processRegionEntry(_ region: CLRegion, at location: CLLocation) async {
        print("🎯 DEBUG: Processing region entry")
        guard let circularRegion = region as? CLCircularRegion,
              let geofence = findGeofence(by: .byRegion(circularRegion)) else {
            print("⚠️ DEBUG: Could not find geofence for region entry: \(region.identifier)")
            return
        }
        
        print("✅ DEBUG: Found geofence for region entry: \(geofence.name ?? "Unknown")")
        updateCurrentGeofence(geofence)
    }
    
    private func processRegionExit(_ region: CLRegion, at location: CLLocation) async {
        print("🚶‍♂️ DEBUG: Processing region exit")
        guard let circularRegion = region as? CLCircularRegion,
              currentGeofence?.name == circularRegion.identifier else {
            print("⚠️ DEBUG: Region exit - no matching current geofence for: \(region.identifier)")
            return
        }
        
        print("✅ DEBUG: Exiting current geofence: \(circularRegion.identifier)")
        updateCurrentGeofence(nil)
    }
    
    // MARK: - Geofence Management
    func startMonitoringGeofence(_ geofence: Geofence) {
        print("🎯 DEBUG: Starting to monitor geofence: \(geofence.name ?? "Unknown")")
        state.shouldSendNotifications = false  // Disable notifications during setup
        
        // Clean up existing monitoring
        stopMonitoringGeofence(geofence)
        
        guard let region = createRegion(for: geofence) else {
            print("⚠️ DEBUG: Failed to create region for geofence: \(geofence.name ?? "Unknown")")
            return
        }
        
        manager.startMonitoring(for: region)
        state.monitoredRegions.insert(region)
        
        print("✅ DEBUG: Successfully started monitoring geofence: \(geofence.name ?? "Unknown")")
        print("📍 DEBUG: Current monitored regions count: \(state.monitoredRegions.count)")
        
        // Start continuous location updates since we're monitoring regions
        manager.startUpdatingLocation()
        print("📍 DEBUG: Started continuous location updates for monitoring")
        
        // Check current location immediately
        if let location = userLocation {
            print("📍 DEBUG: Checking initial position against geofence")
            Task {
                await handleLocationUpdate(location, source: .standard)
            }
        }
        
        // Re-enable notifications after delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            state.shouldSendNotifications = true
            print("🔔 DEBUG: Re-enabled notifications for geofence: \(geofence.name ?? "Unknown")")
        }
    }
    
    func stopMonitoringGeofence(_ geofence: Geofence) {
        let wasInside = currentGeofence?.name == geofence.name
        
        // Remove monitoring
        state.monitoredRegions
            .filter { $0.identifier == geofence.name }
            .forEach { region in
                manager.stopMonitoring(for: region)
                state.monitoredRegions.remove(region)
            }
        
        // Update state if needed
        if wasInside {
            updateCurrentGeofence(nil)
        }
        
        updateMonitoringStatus()
    }
    
    // MARK: - Helper Methods
    private func findGeofence(by method: GeofenceLookupMethod) -> Geofence? {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        
        switch method {
        case .byName(let name):
            fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        case .byRegion(let region):
            fetchRequest.predicate = NSPredicate(format: "name == %@", region.identifier)
        case .byId(let id):
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        }
        
        fetchRequest.fetchLimit = 1
        return try? viewContext.fetch(fetchRequest).first
    }
    
    private func createRegion(for geofence: Geofence) -> CLCircularRegion? {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
              let identifier = geofence.name ?? geofence.id?.uuidString else { return nil }
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            radius: geofence.radius,
            identifier: identifier
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        return region
    }
    
    private func updateMonitoringStatus() {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            Task {
                let activeGeofences = try? await viewContext.perform {
                    try self.findActiveGeofences()
                }
                monitoringStatus = (activeGeofences?.isEmpty ?? true) ? .noGeofences : .ready
            }
        case .notDetermined:
            monitoringStatus = .unknown
        default:
            monitoringStatus = .notAuthorized
        }
    }
    
    private func findActiveGeofences() throws -> [Geofence] {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        return try viewContext.fetch(fetchRequest)
    }
    
    private func checkNotificationSettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus != .authorized {
            print("⚠️ Notifications not authorized - requesting permission")
            await NotificationManager.shared.requestAuthorization()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateMonitoringStatus()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("\n📍 DEBUG: Received location update with \(locations.count) locations")
        guard let location = locations.last else {
            print("⚠️ DEBUG: No location data available")
            return
        }
        
        print("📍 DEBUG: Location accuracy: \(location.horizontalAccuracy)m")
        if location.horizontalAccuracy > 100 {
            print("⚠️ DEBUG: Location accuracy too low, skipping update")
            return
        }
        
        Task {
            print("🔄 DEBUG: Processing location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            await handleLocationUpdate(location, source: .standard)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let location = userLocation else { return }
        
        Task {
            await handleLocationUpdate(location, source: .regionEntry(region))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let location = userLocation else { return }
        
        Task {
            await handleLocationUpdate(location, source: .regionExit(region))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("⚠️ Monitoring failed for region: '\(region?.identifier ?? "Unknown")', error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }
    
    // MARK: - Public Methods
    func requestLocation() {
        print("🎯 DEBUG: Requesting immediate location update")
        manager.requestLocation()
        
        // Ensure continuous updates are running
        if !manager.monitoredRegions.isEmpty {
            print("📍 DEBUG: Starting continuous updates for monitoring")
            manager.startUpdatingLocation()
        }
    }
    
    func checkCurrentLocation() {
        print("🔍 DEBUG: Checking current location")
        // Request immediate update
        manager.requestLocation()
        
        // Print current monitoring state
        print("📍 DEBUG: Currently monitoring \(state.monitoredRegions.count) regions")
        print("📍 DEBUG: Current geofence: \(currentGeofence?.name ?? "None")")
        
        // Ensure continuous updates if needed
        if !state.monitoredRegions.isEmpty {
            manager.startUpdatingLocation()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        locationSubject.send(completion: .finished)
    }
    
    // MARK: - Geofence State Management
    private func updateCurrentGeofence(_ geofence: Geofence?) {
        print("\n🔄 DEBUG: Updating current geofence")
        print("📍 DEBUG: Old geofence: \(currentGeofence?.name ?? "nil")")
        print("📍 DEBUG: New geofence: \(geofence?.name ?? "nil")")
        
        let oldGeofence = currentGeofence
        currentGeofence = geofence
        
        if geofence?.id != oldGeofence?.id {
            print("🔄 DEBUG: Geofence change detected")
            if let geofence = geofence {
                print("➡️ DEBUG: Entering new geofence: \(geofence.name ?? "Unknown")")
                handleGeofenceNotification(type: .entry, geofence: geofence)
            } else if let oldGeofence = oldGeofence {
                print("⬅️ DEBUG: Exiting old geofence: \(oldGeofence.name ?? "Unknown")")
                handleGeofenceNotification(type: .exit, geofence: oldGeofence)
            }
        } else {
            print("ℹ️ DEBUG: No geofence state change needed")
        }
    }
    
    private func handleGeofenceNotification(type: GeofenceNotificationType, geofence: Geofence) {
        print("🔔 DEBUG: Handling geofence notification")
        print("📍 DEBUG: Notifications enabled: \(state.shouldSendNotifications)")
        
        guard state.shouldSendNotifications else {
            print("🔕 DEBUG: Notifications are disabled, skipping notification")
            return
        }
        
        let (title, message) = type.notificationContent(for: geofence)
        print("📱 DEBUG: Scheduling notification - Title: \(title)")
        NotificationManager.shared.scheduleNotification(title: title, body: message)
    }
} 