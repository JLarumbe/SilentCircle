//
//  AddGeofenceViewModel.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//
import SwiftUI
import MapKit

@MainActor
class AddGeofenceViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var radius: Double = 10.0
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var isActive = true
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.0010, longitudeDelta: 0.0010)
    )
    
    private let geofenceListViewModel: GeofenceListViewModel
    
    init(geofenceListViewModel: GeofenceListViewModel) {
        self.geofenceListViewModel = geofenceListViewModel
    }
    
    func updateLocation(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    func createGeofence() {
        geofenceListViewModel.addGeofence(
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius
        )
    }
    
    func radiusToPoints() -> CGFloat {
        let metersPerPoint = region.span.longitudeDelta * 111000 / UIScreen.main.bounds.width
        return (radius * 2) / metersPerPoint
    }
    
    var isValidGeofence: Bool {
        !name.isEmpty && latitude != 0
    }
}
