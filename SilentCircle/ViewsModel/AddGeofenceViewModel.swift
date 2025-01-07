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
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    private var coordinateSubject = PassthroughSubject<(Double, Double), Never>()
    private var keyboardObserver: AnyCancellable?
    
    @Published var pinCoordinate: CLLocationCoordinate2D
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext) {
        self.geofenceListViewModel = geofenceListViewModel
        self.viewContext = viewContext
        self.locationManager = LocationManager()
        
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
            .sink { [weak self] lat, lon in
                self?.latitude = lat
                self?.longitude = lon
            }
            .store(in: &cancellables)
            
        locationManager.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.updateLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            .store(in: &cancellables)
    }
    
    func updateLocation(latitude: Double, longitude: Double) {
        coordinateSubject.send((latitude, longitude))
    }
    
    func createGeofence() async {
        let newGeofence = Geofence(context: viewContext)
        newGeofence.id = UUID()
        newGeofence.name = name
        newGeofence.latitude = latitude
        newGeofence.longitude = longitude
        newGeofence.radius = radius
        newGeofence.isActive = true
        
        PersistenceController.shared.saveIfNeeded()
        await geofenceListViewModel.fetchGeofences()
    }
    
    func radiusToPoints() -> CGFloat {
        guard let region = camera.region else { return 0 }
        let metersPerPoint = region.span.longitudeDelta * 111000 / UIScreen.main.bounds.width
        return (radius * 2) / metersPerPoint
    }
    
    var isValidGeofence: Bool {
        !name.isEmpty
    }
    
    // New helper methods for iOS 17+
    func updateCameraPosition(coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut) {
            camera = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0010, longitudeDelta: 0.0010)
            ))
        }
    }
    
    func getCurrentRegion() -> MKCoordinateRegion? {
        return camera.region
    }
    
    var userLocation: CLLocation? {
        locationManager.userLocation
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    func setupKeyboardObservers(publisher: AnyPublisher<CGFloat, Never>, handler: @escaping (CGFloat) -> Void) {
        keyboardObserver?.cancel()
        keyboardObserver = publisher.sink(receiveValue: handler)
    }
    
    func updatePinLocation(coordinate: CLLocationCoordinate2D) {
        pinCoordinate = coordinate
        updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    func handleMapTap(coordinate: CLLocationCoordinate2D) {
        // Update pin location directly when user taps
        pinCoordinate = coordinate
        updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    deinit {
        cancellables.removeAll()
        keyboardObserver?.cancel()
    }
}
