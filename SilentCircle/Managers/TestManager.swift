import CoreLocation
import CoreData
import UserNotifications

class TestManager: ObservableObject {
    static let shared = TestManager()
    private let testGeofencePrefix = "TEST_"
    private weak var locationManager: LocationManager?
    
    @Published var testLogs: [TestLog] = []
    @Published var isTestMode = false
    
    struct TestLog: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: TestCategory
        let message: String
        let success: Bool
        
        enum TestCategory {
            case geofence
            case notification
            case database
        }
    }
    
    // MARK: - Test Methods
    
    func startTestMode() {
        isTestMode = true
        testLogs.removeAll()
        log(.geofence, "Starting test mode", success: true)
    }
    
    @MainActor
    func stopTestMode() {
        isTestMode = false
        cleanupTestState()
        log(.geofence, "Test mode stopped", success: true)
        
        // Restore actual location state
        if let locationManager = locationManager {
            Task {
                locationManager.checkCurrentLocation()
            }
        }
    }
    
    // Test Geofence Creation
    func testGeofenceCreation(viewContext: NSManagedObjectContext) {
        let testGeofence = Geofence(context: viewContext)
        testGeofence.id = UUID()
        testGeofence.name = "\(testGeofencePrefix)Test Geofence"
        testGeofence.latitude = 37.7749
        testGeofence.longitude = -122.4194
        testGeofence.radius = 100
        testGeofence.isActive = true
        
        do {
            try viewContext.save()
            log(.database, "Created test geofence", success: true)
        } catch {
            log(.database, "Failed to create test geofence: \(error.localizedDescription)", success: false)
        }
    }
    
    // Test Geofence Entry
    @MainActor
    func simulateGeofenceEntry(locationManager: LocationManager, geofence: Geofence) async {
        self.locationManager = locationManager
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
            radius: geofence.radius,
            identifier: geofence.name ?? ""
        )
        
        let location = CLLocation(latitude: geofence.latitude, longitude: geofence.longitude)
        await locationManager.processRegionEntry(region, at: location)
        log(.geofence, "Simulated entry for geofence: \(geofence.name ?? "Unknown")", success: true)
    }
    
    // Test Geofence Exit
    @MainActor
    func simulateGeofenceExit(locationManager: LocationManager, geofence: Geofence) async {
        self.locationManager = locationManager
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
            radius: geofence.radius,
            identifier: geofence.name ?? ""
        )
        
        // Create location just outside the geofence radius
        let location = CLLocation(
            latitude: geofence.latitude + 0.001,  // Slightly north of the geofence
            longitude: geofence.longitude
        )
        await locationManager.processRegionExit(region, at: location)
        log(.geofence, "Simulated exit for geofence: \(geofence.name ?? "Unknown")", success: true)
    }
    
    // Test Notification Delivery
    func testNotificationDelivery() {
        NotificationManager.shared.scheduleNotification(
            title: "Test Notification",
            body: "This is a test notification"
        ) { success in
            self.log(.notification, "Test notification delivery", success: success)
        }
    }
    
    // MARK: - Helper Methods
    
    private func log(_ category: TestLog.TestCategory, _ message: String, success: Bool) {
        let log = TestLog(timestamp: Date(), category: category, message: message, success: success)
        DispatchQueue.main.async {
            self.testLogs.append(log)
        }
        print("🧪 TEST: [\(category)] \(success ? "✅" : "❌") \(message)")
    }
    
    @MainActor
    private func cleanupTestState() {
        let viewContext = PersistenceController.shared.container.viewContext
        
        // Delete test geofences
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name BEGINSWITH %@", testGeofencePrefix)
        
        do {
            let testGeofences = try viewContext.fetch(fetchRequest)
            for geofence in testGeofences {
                viewContext.delete(geofence)
            }
            try viewContext.save()
            log(.database, "Cleaned up \(testGeofences.count) test geofences", success: true)
        } catch {
            log(.database, "Failed to clean up test geofences: \(error.localizedDescription)", success: false)
        }
    }
} 