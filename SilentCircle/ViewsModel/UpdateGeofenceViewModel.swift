//
//  UpdateGeofenceViewModel.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/6/25.
//
import SwiftUI
import MapKit
import CoreData
import Combine

@MainActor
class UpdateGeofenceViewModel: ObservableObject {
    @Published var name: String
    @Published var radius: Double
    @Published var latitude: Double
    @Published var longitude: Double
    @Published var isActive: Bool
    @Published var camera: MapCameraPosition
    @Published var pinCoordinate: CLLocationCoordinate2D
    
    let geofenceListViewModel: GeofenceListViewModel
    private let viewContext: NSManagedObjectContext
    private let geofence: Geofence
    private var cancellables = Set<AnyCancellable>()
    private var coordinateSubject = PassthroughSubject<(Double, Double), Never>()
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext, geofence: Geofence) {
        self.geofenceListViewModel = geofenceListViewModel
        self.viewContext = viewContext
        self.geofence = geofence
        
        // Initialize with existing geofence values
        self.name = geofence.name ?? ""
        self.radius = geofence.radius
        self.latitude = geofence.latitude
        self.longitude = geofence.longitude
        self.isActive = geofence.isActive
        
        // Initialize camera position
        self.camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.0010, longitudeDelta: 0.0010)
        ))
        
        // Initialize pin at geofence location
        self.pinCoordinate = CLLocationCoordinate2D(
            latitude: geofence.latitude,
            longitude: geofence.longitude
        )
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Increase debounce time for smoother updates
        coordinateSubject
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] lat, lon in
                self?.latitude = lat
                self?.longitude = lon
            }
            .store(in: &cancellables)
    }
    
    func updateLocation(latitude: Double, longitude: Double) {
        coordinateSubject.send((latitude, longitude))
    }
    
    var isValidGeofence: Bool {
        !name.isEmpty
    }
    
    func getCurrentRegion() -> MKCoordinateRegion? {
        return camera.region
    }
    
    func handleMapTap(coordinate: CLLocationCoordinate2D) {
        pinCoordinate = coordinate
        updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    deinit {
        cancellables.removeAll()
    }
}


