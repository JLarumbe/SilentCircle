//
//  AddGeofenceViewModel.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//
import SwiftUI
import MapKit
import CoreData
import Combine

@MainActor
class AddGeofenceViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var radius: Double = 10.0
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var isActive = true
    @Published var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.0010, longitudeDelta: 0.0010)
    ))
    
    let geofenceListViewModel: GeofenceListViewModel
    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    private var coordinateSubject = PassthroughSubject<CLLocationCoordinate2D, Never>()
    private var keyboardObserver: AnyCancellable?
    
    @Published var pinCoordinate: CLLocationCoordinate2D
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext) {
        self.geofenceListViewModel = geofenceListViewModel
        self.viewContext = viewContext
        
        // Initialize pin at default location
        self.pinCoordinate = CLLocationCoordinate2D(
            latitude: 37.3346,
            longitude: -122.0090
        )
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Increase debounce time for smoother updates
        coordinateSubject
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] coordinate in
                self?.latitude = coordinate.latitude
                self?.longitude = coordinate.longitude
                self?.pinCoordinate = coordinate
            }
            .store(in: &cancellables)
    }
    
    func updateLocation(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        coordinateSubject.send(coordinate)
    }
    
    var isValidGeofence: Bool {
        !name.isEmpty
    }
    
    func getCurrentRegion() -> MKCoordinateRegion? {
        return camera.region
    }
    
    func handleMapTap(coordinate: CLLocationCoordinate2D) {
        coordinateSubject.send(coordinate)
    }
    
    func createGeofence() async {
        let newGeofence = Geofence(context: viewContext)
        newGeofence.id = UUID()
        newGeofence.name = name
        newGeofence.latitude = latitude
        newGeofence.longitude = longitude
        newGeofence.radius = radius
        newGeofence.isActive = isActive
        
        print("🆕 DEBUG: Creating new geofence")
        print("📍 DEBUG: Location: (\(latitude), \(longitude))")
        print("📏 DEBUG: Radius: \(radius)m")
        
        // Save the context first
        PersistenceController.shared.saveIfNeeded()
        await geofenceListViewModel.fetchGeofences()
        
        // Get the location manager from the list view model
        if let locationManager = geofenceListViewModel.locationManager {
            print("🎯 DEBUG: Starting geofence monitoring")
            locationManager.startMonitoringGeofence(newGeofence)
            
            // Force an immediate location check
            print("🔄 DEBUG: Requesting immediate location check")
            if let location = locationManager.userLocation {
                print("📍 DEBUG: Using current location for immediate check")
                await locationManager.handleLocationUpdate(location, source: .standard)
            } else {
                print("📍 DEBUG: Requesting new location for check")
                locationManager.requestLocation()
            }
        }
    }
    
    deinit {
        cancellables.removeAll()
        keyboardObserver?.cancel()
    }
}
