//
//  SilentCircleTests.swift
//  SilentCircleTests
//
//  Created by Jorge Larumbe on 1/5/25.
//

import Testing
import CoreData
import CoreLocation
import XCTest
@testable import SilentCircle

final class SilentCircleTests: XCTestCase {
    // MARK: - View Model Tests
    
    func testAddGeofenceViewModel() async throws {
        // Setup
        let context = PersistenceController(inMemory: true).container.viewContext
        let listViewModel = await GeofenceListViewModel(viewContext: context)
        let viewModel = await AddGeofenceViewModel(
            geofenceListViewModel: listViewModel,
            viewContext: context
        )
        
        // Test initial state
        await #expect(viewModel.name.isEmpty)
        await #expect(viewModel.radius == 10.0)
        await #expect(viewModel.isValidGeofence == false)
        
        // Test pin placement
        let testCoordinate = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
        await viewModel.handleMapTap(coordinate: testCoordinate)
        await #expect(viewModel.pinCoordinate.latitude == testCoordinate.latitude)
        await #expect(viewModel.pinCoordinate.longitude == testCoordinate.longitude)
        
        // Test geofence creation
        await MainActor.run {
            viewModel.name = "Test Location"
        }
        await #expect(viewModel.isValidGeofence == true)
        await viewModel.createGeofence()
        
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let geofences = try context.fetch(fetchRequest)
        #expect(geofences.count == 1)
        #expect(geofences.first?.name == "Test Location")
    }
    
    func testUpdateGeofenceViewModel() async throws {
        // Setup
        let context = PersistenceController(inMemory: true).container.viewContext
        let listViewModel = await GeofenceListViewModel(viewContext: context)
        
        // Create test geofence
        let geofence = Geofence(context: context)
        geofence.id = UUID()
        geofence.name = "Original Name" 
        geofence.latitude = 37.3346
        geofence.longitude = -122.0090
        geofence.radius = 100
        geofence.isActive = true
        
        let viewModel = await UpdateGeofenceViewModel(
            geofenceListViewModel: listViewModel,
            viewContext: context,
            geofence: geofence
        )
        
        // Test initial state
        await #expect(viewModel.name == "Original Name")
        await #expect(viewModel.radius == 100)
        await #expect(viewModel.isValidGeofence == true)
        
        // Test update
        await MainActor.run {
            viewModel.name = "Updated Name"
            viewModel.radius = 200
        }
        await viewModel.updateGeofence()
        
        #expect(geofence.name == "Updated Name")
        #expect(geofence.radius == 200)
    }
    
    // MARK: - Location Manager Tests
    
    class MockLocationManager: LocationManager {
        override func requestLocation() {
            Task { @MainActor in
                // Simulate a location update
                let mockLocation = CLLocation(latitude: 37.3346, longitude: -122.0090)
                self.userLocation = mockLocation
                // Since we can't access locationSubject directly, we'll use a different approach
                self.locationManager(CLLocationManager(), didUpdateLocations: [mockLocation])
            }
        }
    }
    
    func testLocationManager() async throws {
        let manager = MockLocationManager()
        
        // Test initial state
        #expect(manager.userLocation == nil)
        
        // Test location updates
        let expectation = XCTestExpectation(description: "Location Update")
        
        let cancellable = manager.locationPublisher
            .sink { location in
                Task { @MainActor in
                    #expect(location.coordinate.latitude == 37.3346)
                    #expect(location.coordinate.longitude == -122.0090)
                    expectation.fulfill()
                }
            }
        
        await MainActor.run {
            manager.requestLocation()
        }
        await fulfillment(of: [expectation], timeout: 10.0)  // Increased timeout and ensure we're on MainActor
        cancellable.cancel()
    }
    
    // MARK: - Persistence Tests
    
    func testPersistenceController() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Create test geofence
        let geofence = Geofence(context: context)
        geofence.id = UUID()
        geofence.name = "Test Location"
        geofence.latitude = 37.3346
        geofence.longitude = -122.0090  
        geofence.radius = 100
        geofence.isActive = true
        
        // Save and verify
        PersistenceController.shared.saveIfNeeded()
        
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let geofences = try context.fetch(fetchRequest)
        #expect(geofences.count == 1)
        #expect(geofences.first?.name == "Test Location")
    }
}
