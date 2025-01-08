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
    @Published var radius: Double = 100
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var isActive: Bool = true
    @Published var pinCoordinateWrapper: CoordinateWrapper
    
    private var cancellables = Set<AnyCancellable>()
    private let coordinateSubject = PassthroughSubject<(Double, Double), Never>()
    let geofenceListViewModel: GeofenceListViewModel
    let viewContext: NSManagedObjectContext
    private var mapUpdateTimer: Timer?
    
    var pinCoordinate: CLLocationCoordinate2D {
        pinCoordinateWrapper.coordinate
    }
    
    var isValidGeofence: Bool {
        !name.isEmpty && latitude != 0 && longitude != 0
    }
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext, geofence: Geofence) {
        self.geofenceListViewModel = geofenceListViewModel
        self.viewContext = viewContext
        self.pinCoordinateWrapper = CoordinateWrapper(CLLocationCoordinate2D(
            latitude: geofence.latitude,
            longitude: geofence.longitude
        ))
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        coordinateSubject
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] lat, lon in
                guard let self = self else { return }
                self.latitude = lat
                self.longitude = lon
                self.pinCoordinateWrapper = CoordinateWrapper(CLLocationCoordinate2D(
                    latitude: lat,
                    longitude: lon
                ))
            }
            .store(in: &cancellables)
    }
    
    func updateLocation(latitude: Double, longitude: Double) {
        coordinateSubject.send((latitude, longitude))
    }
    
    func handleMapTap(coordinate: CLLocationCoordinate2D) {
        updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    func getCurrentRegion() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: pinCoordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
        )
    }
    
    func cleanup() {
        mapUpdateTimer?.invalidate()
        mapUpdateTimer = nil
    }
    
    func debounceMapUpdate(_ update: @escaping () -> Void) {
        mapUpdateTimer?.invalidate()
        mapUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            update()
        }
    }
}


