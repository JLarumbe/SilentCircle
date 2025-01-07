//
//  AddGeofenceViewModel.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//
import SwiftUI
import MapKit
import CoreData

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
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext) {
        self.geofenceListViewModel = geofenceListViewModel
        self.viewContext = viewContext
    }
    
    func updateLocation(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
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
}
