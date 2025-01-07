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
    @Published var name: String = ""
    @Published var radius: Double = 10.0
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var isActive = true
    @Published var camera: MapCameraPosition
    
    let geofenceListViewModel: GeofenceListViewModel
    private let viewContext: NSManagedObjectContext
    private let geofence: Geofence
    
    private var coordinateSubject = PassthroughSubject<(Double, Double), Never>()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var pinCoordinate: CLLocationCoordinate2D
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext, geofence: Geofence) {
        self.geofenceListViewModel = geofenceListViewModel
        self.viewContext = viewContext
        self.geofence = geofence
        
        // Initialize with existing geofence data
        self.name = geofence.name ?? ""
        self.radius = geofence.radius
        self.latitude = geofence.latitude
        self.longitude = geofence.longitude
        self.isActive = geofence.isActive
        
        // Initialize pin at geofence location
        self.pinCoordinate = CLLocationCoordinate2D(
            latitude: geofence.latitude,
            longitude: geofence.longitude
        )
        
        // Initialize camera position
        self.camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.0010, longitudeDelta: 0.0010)
        ))
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
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
    
    func updateGeofence() async {
        geofence.name = name
        geofence.latitude = latitude
        geofence.longitude = longitude
        geofence.radius = radius
        geofence.isActive = isActive
        
        PersistenceController.shared.saveIfNeeded()
        await geofenceListViewModel.fetchGeofences()
    }
    
    var isValidGeofence: Bool {
        !name.isEmpty && latitude != 0
    }
    
    func updatePinLocation(coordinate: CLLocationCoordinate2D) {
        pinCoordinate = coordinate
        updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    func handleMapTap(coordinate: CLLocationCoordinate2D) {
        pinCoordinate = coordinate
        updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    func getCurrentRegion() -> MKCoordinateRegion? {
        return camera.region
    }
}


