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

private enum LocationAccuracyMode: Equatable {
    case precise    // When near or inside geofence
    case balanced   // When within warning distance
    case efficient  // When far from all geofences
    
    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .precise:   return kCLLocationAccuracyBest
        case .balanced:  return kCLLocationAccuracyNearestTenMeters
        case .efficient: return kCLLocationAccuracyHundredMeters
        }
    }
    
    var distanceFilter: CLLocationDistance {
        switch self {
        case .precise:   return 5     // Update every 5 meters
        case .balanced:  return 20    // Update every 20 meters
        case .efficient: return 100   // Update every 100 meters
        }
    }
}

private struct GeofenceState {
    var monitoredRegions: Set<CLCircularRegion> = []
    var lastLocationUpdate: Date?
    var shouldSendNotifications = true
    var accuracyMode: LocationAccuracyMode = .balanced
    
    // Distance thresholds in meters
    static let warningDistance: CLLocationDistance = 200
    static let preciseDistance: CLLocationDistance = 50
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
        print("🔧 DEBUG: Initializing location manager setup")
        
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        print("🔋 DEBUG: Battery monitoring enabled")
        
        // Initial setup with balanced accuracy
        manager.desiredAccuracy = LocationAccuracyMode.balanced.desiredAccuracy
        manager.distanceFilter = LocationAccuracyMode.balanced.distanceFilter
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.delegate = self
        print("⚙️ DEBUG: Location manager configured with balanced accuracy mode")
        
        // Request authorization
        manager.requestAlwaysAuthorization()
        print("🔐 DEBUG: Requested 'Always' location authorization")
        
        Task {
            await checkNotificationSettings()
            updateMonitoringStatus()
            
            // Start continuous updates only if we have regions to monitor
            updateLocationMonitoring()
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
        print("\n📡 DEBUG: Processing location update")
        print("📍 DEBUG: Location: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("📏 DEBUG: Accuracy: \(Int(location.horizontalAccuracy))m")
        
        // Update accuracy based on location and battery
        updateLocationAccuracy(for: location)
        
        // Always update monitoring status when processing location
        await updateMonitoringStatus()
        
        guard !state.monitoredRegions.isEmpty else {
            print("⚠️ DEBUG: No active geofence regions found")
            return
        }
        print("🎯 DEBUG: Monitoring \(state.monitoredRegions.count) geofence regions")
        
        var foundActiveGeofence = false
        for region in state.monitoredRegions {
            guard let geofence = findGeofence(by: .byRegion(region)) else {
                print("⚠️ DEBUG: Failed to find geofence data for region: \(region.identifier)")
                continue
            }
            
            let center = CLLocation(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            )
            
            let distance = location.distance(from: center)
            print("📍 DEBUG: '\(geofence.name ?? "Unknown")' - Distance: \(Int(distance))m, Radius: \(Int(geofence.radius))m")
            
            if distance <= geofence.radius {
                print("✅ DEBUG: Inside geofence '\(geofence.name ?? "Unknown")'")
                updateCurrentGeofence(geofence)
                foundActiveGeofence = true
                break
            }
        }
        
        if !foundActiveGeofence && currentGeofence != nil {
            print("🚫 DEBUG: Left all geofence regions, clearing active geofence")
            updateCurrentGeofence(nil)
        }
    }
    
    private func processRegionEntry(_ region: CLRegion, at location: CLLocation) async {
        print("\n🎯 DEBUG: Processing geofence region entry")
        guard let circularRegion = region as? CLCircularRegion,
              let geofence = findGeofence(by: .byRegion(circularRegion)) else {
            print("⚠️ DEBUG: Failed to find geofence data for region entry: \(region.identifier)")
            return
        }
        
        print("✅ DEBUG: Entered geofence region: \(geofence.name ?? "Unknown")")
        updateCurrentGeofence(geofence)
    }
    
    private func processRegionExit(_ region: CLRegion, at location: CLLocation) async {
        print("\n🚶‍♂️ DEBUG: Processing geofence region exit")
        guard let circularRegion = region as? CLCircularRegion,
              currentGeofence?.name == circularRegion.identifier else {
            print("⚠️ DEBUG: No matching current geofence for region exit: \(region.identifier)")
            return
        }
        
        print("✅ DEBUG: Exited geofence region: \(circularRegion.identifier)")
        updateCurrentGeofence(nil)
    }
    
    // MARK: - Geofence Management
    func startMonitoringGeofence(_ geofence: Geofence) {
        print("\n🎯 DEBUG: Starting geofence monitoring")
        print("📍 DEBUG: Geofence: '\(geofence.name ?? "Unknown")' at (\(geofence.latitude), \(geofence.longitude))")
        
        state.shouldSendNotifications = false
        print("🔕 DEBUG: Temporarily disabled notifications during setup")
        
        // Clean up existing monitoring
        stopMonitoringGeofence(geofence)
        
        guard let region = createRegion(for: geofence) else {
            print("❌ DEBUG: Failed to create monitoring region for: \(geofence.name ?? "Unknown")")
            return
        }
        
        manager.startMonitoring(for: region)
        state.monitoredRegions.insert(region)
        
        print("✅ DEBUG: Successfully started monitoring geofence")
        print("📊 DEBUG: Total monitored regions: \(state.monitoredRegions.count)")
        
        // Update continuous monitoring state
        updateLocationMonitoring()
        
        // Check current location
        if let location = userLocation {
            print("🔍 DEBUG: Checking initial position against geofence")
            Task {
                await handleLocationUpdate(location, source: .standard)
            }
        }
        
        // Re-enable notifications after delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            state.shouldSendNotifications = true
            print("🔔 DEBUG: Re-enabled notifications for geofence")
        }
    }
    
    func stopMonitoringGeofence(_ geofence: Geofence) {
        print("\n🛑 DEBUG: Stopping geofence monitoring")
        print("📍 DEBUG: Geofence: '\(geofence.name ?? "Unknown")'")
        
        let wasInside = currentGeofence?.name == geofence.name
        
        // Remove monitoring
        state.monitoredRegions
            .filter { $0.identifier == geofence.name }
            .forEach { region in
                manager.stopMonitoring(for: region)
                state.monitoredRegions.remove(region)
                print("✅ DEBUG: Stopped monitoring region: \(region.identifier)")
            }
        
        // Update state if needed
        if wasInside {
            updateCurrentGeofence(nil)
        }
        
        // Update continuous monitoring state
        updateLocationMonitoring()
        
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
        
        // Update continuous monitoring state
        updateLocationMonitoring()
    }
    
    func checkCurrentLocation() {
        print("🔍 DEBUG: Checking current location")
        // Request immediate update
        manager.requestLocation()
        
        // Print current monitoring state
        print("📍 DEBUG: Currently monitoring \(state.monitoredRegions.count) regions")
        print("📍 DEBUG: Current geofence: \(currentGeofence?.name ?? "None")")
        
        // Update continuous monitoring state
        updateLocationMonitoring()
    }
    
    // MARK: - Cleanup
    deinit {
        locationSubject.send(completion: .finished)
    }
    
    // MARK: - Geofence State Management
    private func updateCurrentGeofence(_ geofence: Geofence?) {
        print("\n🔄 DEBUG: Updating active geofence")
        print("📍 DEBUG: Previous: \(currentGeofence?.name ?? "None")")
        print("📍 DEBUG: New: \(geofence?.name ?? "None")")
        
        let oldGeofence = currentGeofence
        currentGeofence = geofence
        
        if geofence?.id != oldGeofence?.id {
            print("🔄 DEBUG: Geofence state change detected")
            if let geofence = geofence {
                print("➡️ DEBUG: Entering: \(geofence.name ?? "Unknown")")
                handleGeofenceNotification(type: .entry, geofence: geofence)
            } else if let oldGeofence = oldGeofence {
                print("⬅️ DEBUG: Exiting: \(oldGeofence.name ?? "Unknown")")
                handleGeofenceNotification(type: .exit, geofence: oldGeofence)
            }
        } else {
            print("ℹ️ DEBUG: No geofence state change needed")
        }
    }
    
    private func handleGeofenceNotification(type: GeofenceNotificationType, geofence: Geofence) {
        print("\n🔔 DEBUG: Processing geofence notification")
        print("📱 DEBUG: Notification state: \(state.shouldSendNotifications ? "Enabled" : "Disabled")")
        
        guard state.shouldSendNotifications else {
            print("🔕 DEBUG: Notifications disabled, skipping")
            return
        }
        
        let (title, message) = type.notificationContent(for: geofence)
        print("📱 DEBUG: Scheduling notification")
        print("📝 DEBUG: Title: \(title)")
        print("📝 DEBUG: Message: \(message)")
        NotificationManager.shared.scheduleNotification(title: title, body: message)
    }
    
    private func updateLocationAccuracy(for location: CLLocation) {
        let batteryLevel = UIDevice.current.batteryLevel
        var closestDistance = CLLocationDistance.greatestFiniteMagnitude
        
        print("\n⚡️ DEBUG: Updating location accuracy settings")
        print("🔋 DEBUG: Current battery level: \(Int(batteryLevel * 100))%")
        
        // Find closest geofence
        for region in state.monitoredRegions {
            guard let geofence = findGeofence(by: .byRegion(region)) else { continue }
            
            let center = CLLocation(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            )
            let distance = location.distance(from: center)
            closestDistance = min(closestDistance, distance)
        }
        
        // Determine new accuracy mode
        let newMode: LocationAccuracyMode
        if closestDistance <= GeofenceState.preciseDistance || batteryLevel > 0.7 {
            newMode = .precise
        } else if closestDistance <= GeofenceState.warningDistance || batteryLevel > 0.3 {
            newMode = .balanced
        } else {
            newMode = .efficient
        }
        
        // Update if mode changed
        if newMode != state.accuracyMode {
            state.accuracyMode = newMode
            manager.desiredAccuracy = newMode.desiredAccuracy
            manager.distanceFilter = newMode.distanceFilter
            print("⚙️ DEBUG: Updated accuracy mode: \(String(describing: newMode))")
            print("📏 DEBUG: Closest geofence: \(Int(closestDistance))m")
            print("⚡️ DEBUG: New distance filter: \(Int(newMode.distanceFilter))m")
        }
    }
    
    // MARK: - Location Monitoring Management
    private func updateLocationMonitoring() {
        print("\n📡 DEBUG: Updating location monitoring state")
        
        if state.monitoredRegions.isEmpty {
            print("📍 DEBUG: No regions to monitor, stopping continuous updates")
            manager.stopUpdatingLocation()
        } else {
            print("📍 DEBUG: Monitoring \(state.monitoredRegions.count) regions, ensuring continuous updates")
            manager.startUpdatingLocation()
        }
    }
} 