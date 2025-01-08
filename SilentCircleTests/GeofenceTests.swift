import XCTest
import CoreLocation
import CoreData
@testable import SilentCircle

final class GeofenceTests: XCTestCase {
    var locationManager: MockLocationManager!
    var notificationManager: MockNotificationManager!
    var context: NSManagedObjectContext!
    var viewModel: GeofenceListViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        locationManager = MockLocationManager()
        notificationManager = MockNotificationManager()
        NotificationManager.shared = notificationManager
        
        // Create persistence controller - removed try since init doesn't throw
        let persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        
        await MainActor.run {
            viewModel = GeofenceListViewModel(viewContext: context)
        }
    }
    
    func testGeofenceCreationAndMonitoring() async throws {
        // Create test geofence
        let geofence = Geofence(context: context)
        geofence.id = UUID()
        geofence.name = "Apple Park"
        geofence.latitude = 37.3346
        geofence.longitude = -122.0090
        geofence.radius = 100
        geofence.isActive = true
        
        try context.save()
        
        // Start monitoring
        locationManager.startMonitoringGeofence(geofence)
        
        // Verify region is being monitored
        XCTAssertTrue(locationManager.monitoredRegions.contains { region in
            region.identifier == geofence.name
        })
        
        // Test initial location check (inside geofence)
        let insideLocation = CLLocation(latitude: 37.3346, longitude: -122.0090)
        locationManager.simulateLocationUpdate(insideLocation)
        
        // Verify notification was sent
        XCTAssertTrue(notificationManager.notifications.contains { notification in
            notification.title == "Entering Silent Circle (Apple Park)" &&
            notification.body == "Notifications will be turned off until you leave."
        })
        
        // Clear notifications for next test
        notificationManager.notifications.removeAll()
        
        // Test moving outside
        let outsideLocation = CLLocation(latitude: 37.3356, longitude: -122.0100)
        locationManager.simulateLocationUpdate(outsideLocation)
        locationManager.simulateExitRegion(geofence)
        
        XCTAssertTrue(notificationManager.notifications.contains { notification in
            notification.title == "Exiting Silent Circle (Apple Park)" &&
            notification.body == "Notifications have been restored."
        })
    }
    
    func testGeofenceActivationAndDeactivation() async throws {
        // Create inactive geofence
        let geofence = Geofence(context: context)
        geofence.id = UUID()
        geofence.name = "Test Zone"
        geofence.latitude = 37.3346
        geofence.longitude = -122.0090
        geofence.radius = 100
        geofence.isActive = false
        
        try context.save()
        
        // Test activation
        await MainActor.run {
            viewModel.updateGeofenceMonitoring(geofence, locationManager: locationManager)
        }
        
        XCTAssertFalse(locationManager.monitoredRegions.contains { region in
            region.identifier == geofence.name
        })
        
        // Activate geofence
        geofence.isActive = true
        await MainActor.run {
            viewModel.updateGeofenceMonitoring(geofence, locationManager: locationManager)
        }
        
        XCTAssertTrue(locationManager.monitoredRegions.contains { region in
            region.identifier == geofence.name
        })
        
        // Test deactivation
        geofence.isActive = false
        await MainActor.run {
            viewModel.updateGeofenceMonitoring(geofence, locationManager: locationManager)
        }
        
        XCTAssertFalse(locationManager.monitoredRegions.contains { region in
            region.identifier == geofence.name
        })
    }
    
    func testGeofenceDeletion() async throws {
        // Create geofence
        let geofence = Geofence(context: context)
        geofence.id = UUID()
        geofence.name = "Test Zone"
        geofence.latitude = 37.3346
        geofence.longitude = -122.0090
        geofence.radius = 100
        geofence.isActive = true
        
        try context.save()
        
        // Start monitoring
        locationManager.startMonitoringGeofence(geofence)
        
        // Delete geofence
        await MainActor.run {
            viewModel.deleteItems(at: [0], locationManager: locationManager)
        }
        
        // Verify monitoring stopped
        XCTAssertFalse(locationManager.monitoredRegions.contains { region in
            region.identifier == geofence.name
        })
        
        // Verify geofence was deleted
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let remainingGeofences = try context.fetch(fetchRequest)
        XCTAssertTrue(remainingGeofences.isEmpty)
    }
}

// MARK: - Mock Location Manager
class MockLocationManager: LocationManager {
    override func startMonitoringGeofence(_ geofence: Geofence) {
        super.startMonitoringGeofence(geofence)
    }
    
    func simulateLocationUpdate(_ location: CLLocation) {
        self.locationManager(manager, didUpdateLocations: [location])
    }
    
    func simulateExitRegion(_ geofence: Geofence) {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            radius: geofence.radius,
            identifier: geofence.name ?? geofence.id?.uuidString ?? UUID().uuidString
        )
        self.locationManager(manager, didExitRegion: region)
    }
} 
