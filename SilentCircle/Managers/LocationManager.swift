import CoreLocation
import MapKit
import Combine
import CoreData
import UserNotifications

// MARK: - Supporting Types

/// Source of a location update
enum LocationUpdateSource {
    /// Standard location update from CoreLocation
    case standard
    /// Update triggered by entering a monitored region
    case regionEntry(CLRegion)
    /// Update triggered by exiting a monitored region
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
    var lastGeofenceStateChange: Date?
    
    // Distance thresholds in meters
    static let warningDistance: CLLocationDistance = 200
    static let preciseDistance: CLLocationDistance = 50
    // Hysteresis: require being 2 meters inside/outside the boundary to change state
    static let hysteresisBuffer: CLLocationDistance = 2
    // Minimum time between geofence state changes
    static let minimumStateChangeInterval: TimeInterval = 30
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    let manager: CLLocationManager
    private let viewContext: NSManagedObjectContext
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let minimumLocationUpdateInterval: TimeInterval = 1.0
    private var state = GeofenceState()
    private var isInitialSetupComplete = false
    private var isSingleLocationRequest = false
    private var isCreatingGeofence = false
    
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
        guard !isInitialSetupComplete else {
            print("ℹ️ DEBUG: Setup already completed, skipping")
            return
        }
        
        print("🔧 DEBUG: Initializing location manager setup")
        
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        print("🔋 DEBUG: Battery monitoring enabled")
        
        // Initial setup with balanced accuracy
        manager.desiredAccuracy = LocationAccuracyMode.balanced.desiredAccuracy
        manager.distanceFilter = LocationAccuracyMode.balanced.distanceFilter
        manager.allowsBackgroundLocationUpdates = true
        #if os(iOS)
        manager.showsBackgroundLocationIndicator = true
        #endif
        manager.pausesLocationUpdatesAutomatically = false
        manager.delegate = self
        print("⚙️ DEBUG: Location manager configured with balanced accuracy mode")
        
        // Request authorization
        manager.requestAlwaysAuthorization()
        print("🔐 DEBUG: Requested 'Always' location authorization")
        
        Task {
            await checkNotificationSettings()
            updateMonitoringStatus()
            
            // Start monitoring any active geofences
            do {
                let activeGeofences = try await viewContext.perform {
                    try self.findActiveGeofences()
                }
                print("📍 DEBUG: Found \(activeGeofences.count) active geofences")
                
                // Clear existing monitoring
                state.monitoredRegions.forEach { region in
                    manager.stopMonitoring(for: region)
                }
                state.monitoredRegions.removeAll()
                currentGeofence = nil
                
                // Start fresh monitoring with notifications initially enabled
                state.shouldSendNotifications = true
                
                // Start monitoring all active geofences
                for geofence in activeGeofences {
                    startMonitoringGeofence(geofence)
                }
                
                // Mark setup as complete
                isInitialSetupComplete = true
                
                // Initialize location monitoring if we have active geofences
                if !activeGeofences.isEmpty {
                    print("🎯 DEBUG: Initializing location monitoring for active geofences")
                    // If we already have a location, process it immediately
                    if let location = userLocation {
                        print("📍 DEBUG: Using existing location for initial check")
                        await handleLocationUpdate(location, source: .standard)
                    } else {
                        print("📍 DEBUG: No location available, requesting single update")
                        manager.requestLocation()
                    }
                } else {
                    print("📍 DEBUG: No active geofences, skipping location monitoring")
                }
            } catch {
                print("⚠️ DEBUG: Failed to fetch active geofences: \(error)")
            }
        }
    }
    
    // MARK: - Location Handling
    func handleLocationUpdate(_ location: CLLocation, source: LocationUpdateSource) async {
        print("\n🔄 DEBUG: Starting location update")
        print("  - Source: \(source)")
        print("  - Is creating geofence: \(isCreatingGeofence)")
        print("  - Is single location request: \(isSingleLocationRequest)")
        
        let now = Date()
        
        // Check update interval and skip if too soon
        if let lastUpdate = state.lastLocationUpdate,
           now.timeIntervalSince(lastUpdate) < minimumLocationUpdateInterval {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdate)
            print("⏱️ DEBUG: Skipping update - too soon since last update (\(String(format: "%.1f", timeSinceLastUpdate))s)")
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
        
        // Reset flags only after everything is complete
        if isSingleLocationRequest {
            print("  - Resetting single location request flags")
            print("  - Final update complete")
            isSingleLocationRequest = false
            isCreatingGeofence = false
        }
    }
    
    private func processStandardLocationUpdate(_ location: CLLocation) async {
        print("\n📡 DEBUG: Processing location update")
        print("📍 DEBUG: Location: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("📏 DEBUG: Accuracy: \(Int(location.horizontalAccuracy))m")
        
        // Skip updates with poor accuracy
        guard location.horizontalAccuracy <= 50 else {
            print("⚠️ DEBUG: Location accuracy too poor for geofence detection")
            return
        }
        
        // Only update accuracy and monitoring for continuous monitoring
        if !isSingleLocationRequest {
            // Update accuracy based on location and battery
            updateLocationAccuracy(for: location)
            await updateMonitoringStatus()
        }
        
        guard !state.monitoredRegions.isEmpty else {
            print("⚠️ DEBUG: No active geofence regions found")
            return
        }
        print("🎯 DEBUG: Monitoring \(state.monitoredRegions.count) geofence regions")
        
        // Skip state change throttling during initial setup or if no current geofence
        let shouldThrottle = isInitialSetupComplete && currentGeofence != nil
        var shouldUpdateState = !shouldThrottle
        
        if shouldThrottle {
            // Check if enough time has passed since last state change
            if let lastChange = state.lastGeofenceStateChange {
                let timeSinceLastChange = Date().timeIntervalSince(lastChange)
                shouldUpdateState = timeSinceLastChange >= GeofenceState.minimumStateChangeInterval
                if !shouldUpdateState {
                    print("⏳ DEBUG: Skipping state change, only \(Int(timeSinceLastChange))s since last change")
                }
            } else {
                // No last change recorded, allow update
                shouldUpdateState = true
            }
        }
        
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
                foundActiveGeofence = true
                
                // Update state if needed and allowed
                if shouldUpdateState && currentGeofence?.id != geofence.id {
                    print("🔄 DEBUG: Updating current geofence state")
                    state.lastGeofenceStateChange = Date()
                    updateCurrentGeofence(geofence)
                } else if currentGeofence?.id != geofence.id {
                    print("ℹ️ DEBUG: Inside geofence but skipping state update due to throttling")
                }
                break
            }
        }
        
        // Handle exit state if needed
        if !foundActiveGeofence && currentGeofence != nil && shouldUpdateState {
            print("🚫 DEBUG: Left all geofence regions, clearing active geofence")
            state.lastGeofenceStateChange = Date()
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
    private var pendingNotificationEnablements = Set<String>()
    
    func startMonitoringGeofence(_ geofence: Geofence) {
        print("\n🎯 DEBUG: Starting geofence monitoring")
        print("📍 DEBUG: Geofence: '\(geofence.name ?? "Unknown")' at (\(geofence.latitude), \(geofence.longitude))")
        
        // Check if we're already monitoring this geofence
        if state.monitoredRegions.contains(where: { $0.identifier == geofence.name }) {
            print("ℹ️ DEBUG: Already monitoring this geofence")
            return
        }
        
        // Create the region
        guard let region = createRegion(for: geofence) else {
            print("⚠️ DEBUG: Failed to create region for geofence")
            return
        }
        
        // Start monitoring
        manager.startMonitoring(for: region)
        state.monitoredRegions.insert(region)
        print("✅ DEBUG: Successfully started monitoring geofence")
        print("📊 DEBUG: Total monitored regions: \(state.monitoredRegions.count)")
        
        // Update monitoring state
        updateLocationMonitoring()
        
        // If we have a current location, check if we're inside this geofence
        if let location = userLocation {
            print("🔍 DEBUG: Checking initial position against geofence")
            Task {
                await handleLocationUpdate(location, source: .standard)
            }
        } else {
            print("⚠️ DEBUG: No location available yet, will check when location updates")
            requestLocation()
        }
    }
    
    func stopMonitoringGeofence(_ geofence: Geofence) {
        print("🛑 DEBUG: Stopping monitoring for geofence: \(geofence.name ?? "Unknown")")
        
        // Find and stop monitoring the region
        if let region = state.monitoredRegions.first(where: { $0.identifier == geofence.name }) {
            manager.stopMonitoring(for: region)
            state.monitoredRegions.remove(region)
            print("✅ DEBUG: Successfully removed region from monitoring")
            
            // Clear current geofence if it's the one we're stopping
            if currentGeofence?.id == geofence.id {
                print("🔄 DEBUG: Clearing current geofence as it's being deactivated")
                currentGeofence = nil
                objectWillChange.send()
            }
        }
        
        updateMonitoringStatus()
    }
    
    func updateGeofence(_ geofence: Geofence) {
        print("🔄 DEBUG: Updating geofence: \(geofence.name ?? "Unknown")")
        
        // Stop monitoring old region if it exists
        stopMonitoringGeofence(geofence)
        
        // Create and start monitoring new region
        guard let region = createRegion(for: geofence) else {
            print("⚠️ DEBUG: Failed to create region for geofence")
            return
        }
        
        manager.startMonitoring(for: region)
        state.monitoredRegions.insert(region)
        
        // Update monitoring status
        updateMonitoringStatus()
        
        // Check if we need to update current geofence
        if let location = userLocation {
            Task {
                await handleLocationUpdate(location, source: .standard)
            }
        }
        
        print("✅ DEBUG: Successfully updated geofence monitoring")
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
        print("\n🔍 DEBUG: Updating monitoring status")
        print("  - Current status: \(monitoringStatus)")
        print("  - Is creating geofence: \(isCreatingGeofence)")
        print("  - Is single location request: \(isSingleLocationRequest)")
        print("  - Stack trace:")
        Thread.callStackSymbols.prefix(5).forEach { print("    \($0)") }
        
        // Don't update status during geofence creation
        guard !isCreatingGeofence else {
            print("ℹ️ DEBUG: Skipping monitoring status update during geofence creation")
            return
        }

        switch manager.authorizationStatus {
        case .authorizedAlways:
            Task {
                let activeGeofences = try? await viewContext.perform {
                    try self.findActiveGeofences()
                }
                let newStatus: MonitoringStatus = (activeGeofences?.isEmpty ?? true) ? .noGeofences : .ready
                print("  - Authorization: .authorizedAlways")
                print("  - Active geofences: \(activeGeofences?.count ?? 0)")
                print("  - New status: \(newStatus)")
                monitoringStatus = newStatus
            }
        case .notDetermined:
            print("  - Authorization: .notDetermined")
            monitoringStatus = .unknown
        default:
            print("  - Authorization: \(manager.authorizationStatus)")
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
        print("  - Stack trace:")
        Thread.callStackSymbols.prefix(5).forEach { print("    \($0)") }
        
        guard let location = locations.last else {
            print("⚠️ DEBUG: No location data available")
            return
        }
        
        print("📍 DEBUG: Location accuracy: \(location.horizontalAccuracy)m")
        if location.horizontalAccuracy > 100 {
            print("⚠️ DEBUG: Location accuracy too low, skipping update")
            return
        }
        
        // Skip if this is a duplicate location
        if let lastLocation = userLocation {
            let isSameLocation = lastLocation.coordinate.latitude == location.coordinate.latitude &&
                               lastLocation.coordinate.longitude == location.coordinate.longitude
            let isRecentUpdate = state.lastLocationUpdate.map { 
                Date().timeIntervalSince($0) < minimumLocationUpdateInterval 
            } ?? false
            
            if isSameLocation {
                print("ℹ️ DEBUG: Skipping duplicate location update")
                return
            }
            
            if isRecentUpdate {
                print("⏱️ DEBUG: Skipping update - too soon since last update")
                return
            }
        }
        
        Task {
            print("🔄 DEBUG: Processing location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            print("  - Is creating geofence: \(isCreatingGeofence)")
            print("  - Is single location request: \(isSingleLocationRequest)")
            await handleLocationUpdate(location, source: .standard)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("\n📍 DEBUG: Did enter region: \(region.identifier)")
        handleGeofenceEvent(region, didEnter: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("\n📍 DEBUG: Did exit region: \(region.identifier)")
        handleGeofenceEvent(region, didEnter: false)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("⚠️ Monitoring failed for region: '\(region?.identifier ?? "Unknown")', error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }
    
    // MARK: - Public Methods
    func requestLocation() {
        print("\n🎯 DEBUG: Requesting immediate location update")
        print("  - Stack trace:")
        Thread.callStackSymbols.prefix(5).forEach { print("    \($0)") }
        isSingleLocationRequest = true
        isCreatingGeofence = true  // Set flag to prevent monitoring status updates
        manager.requestLocation()
    }
    
    func checkCurrentLocation() {
        print("🔍 DEBUG: Checking current location")
        isSingleLocationRequest = false
        isCreatingGeofence = false  // Allow monitoring status updates for normal checks
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
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled", defaultValue: false)
        print("📱 DEBUG: Notifications setting in UserDefaults: \(notificationsEnabled)")
        print("📱 DEBUG: Notification state: \(state.shouldSendNotifications ? "Enabled" : "Disabled")")
        
        // Check both UserDefaults and internal state
        guard notificationsEnabled && state.shouldSendNotifications else {
            print("🔕 DEBUG: Notifications disabled, skipping")
            print("  - UserDefaults setting: \(notificationsEnabled)")
            print("  - Internal state: \(state.shouldSendNotifications)")
            return
        }
        
        let (title, message) = type.notificationContent(for: geofence)
        print("📱 DEBUG: Scheduling notification")
        print("📝 DEBUG: Title: \(title)")
        print("📝 DEBUG: Message: \(message)")
        NotificationManager.shared.scheduleNotification(title: title, body: message)
    }
    
    private func updateLocationAccuracy(for location: CLLocation) {
        let rawBatteryLevel = UIDevice.current.batteryLevel
        let batteryLevel = rawBatteryLevel < 0 ? 1.0 : rawBatteryLevel  // Default to 100% if battery level is unknown
        var closestDistance = CLLocationDistance.greatestFiniteMagnitude
        
        print("\n⚡️ DEBUG: Updating location accuracy settings")
        print("🔋 DEBUG: Current battery level: \(String(format: "%.0f", batteryLevel * 100))% \(rawBatteryLevel < 0 ? "(Unknown)" : "")")
        
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
            print("📏 DEBUG: Closest geofence: \(closestDistance.formatted(unit: DistanceUnit(rawValue: UserDefaults.standard.string(forKey: "distanceUnit") ?? "") ?? .kilometers))")
            print("⚡️ DEBUG: New distance filter: \(newMode.distanceFilter.formatted(unit: DistanceUnit(rawValue: UserDefaults.standard.string(forKey: "distanceUnit") ?? "") ?? .kilometers))")
        }
    }
    
    // MARK: - Location Monitoring Management
    private func updateLocationMonitoring() {
        // Get current state
        let hasMonitoredRegions = !state.monitoredRegions.isEmpty
        let isUpdatingLocation = manager.monitoredRegions.count > 0
        let hasRecentLocation = userLocation != nil && 
                              (state.lastLocationUpdate.map { Date().timeIntervalSince($0) <= 30 } ?? false)
        
        print("\n📡 DEBUG: Updating location monitoring state")
        print("📍 DEBUG: Has monitored regions: \(hasMonitoredRegions)")
        print("📍 DEBUG: Is updating location: \(isUpdatingLocation)")
        print("📍 DEBUG: Has recent location: \(hasRecentLocation)")
        
        // Avoid redundant updates if monitoring state hasn't changed
        if hasMonitoredRegions == isUpdatingLocation {
            print("ℹ️ DEBUG: Monitoring state unchanged, skipping update")
            return
        }
        
        if state.monitoredRegions.isEmpty {
            print("📍 DEBUG: No regions to monitor, stopping continuous updates")
            manager.stopUpdatingLocation()
        } else {
            print("📍 DEBUG: Monitoring \(state.monitoredRegions.count) regions")
            // Only start updates if we don't have a recent location
            if !hasRecentLocation {
                print("📍 DEBUG: Starting continuous updates")
                manager.startUpdatingLocation()
            } else {
                print("📍 DEBUG: Using recent location, deferring updates")
            }
        }
    }
    
    private func handleGeofenceEvent(_ region: CLRegion, didEnter: Bool) {
        print("\n🌍 DEBUG: Handling geofence event")
        print("  - Region: \(region.identifier)")
        print("  - Event: \(didEnter ? "Entry" : "Exit")")
        
        // Check notification setting early
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled", defaultValue: false)
        print("🔔 DEBUG: Notifications enabled in settings: \(notificationsEnabled)")
        
        // Get the geofence from Core Data
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", region.identifier)
        
        do {
            if let geofence = try viewContext.fetch(fetchRequest).first {
                // Update current geofence
                currentGeofence = didEnter ? geofence : nil
                
                // Handle sound mode changes
                if didEnter {
                    NotificationManager.shared.handleGeofenceEntry()
                    if notificationsEnabled {
                        handleGeofenceNotification(type: .entry, geofence: geofence)
                    } else {
                        print("🔕 DEBUG: Notifications disabled in settings, skipping notification")
                    }
                } else {
                    NotificationManager.shared.handleGeofenceExit()
                    if notificationsEnabled {
                        handleGeofenceNotification(type: .exit, geofence: geofence)
                    } else {
                        print("🔕 DEBUG: Notifications disabled in settings, skipping notification")
                    }
                }
                
                print("✅ DEBUG: Successfully handled geofence \(didEnter ? "entry" : "exit")")
            }
        } catch {
            print("❌ DEBUG: Failed to fetch geofence: \(error.localizedDescription)")
        }
    }
} 