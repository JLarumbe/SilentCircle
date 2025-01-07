//
//  UpdateGeofenceViewModel.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/6/25.
//
import SwiftUI
import MapKit
import CoreData

@MainActor
class UpdateGeofenceViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var radius: Double = 10.0
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var isActive = true
    
    let geofenceListViewModel: GeofenceListViewModel
    private let viewContext: NSManagedObjectContext
    private let geofence: Geofence
    
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
    }
    
    func updateLocation(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    func updateGeofence() {
        geofence.name = name
        geofence.latitude = latitude
        geofence.longitude = longitude
        geofence.radius = radius
        geofence.isActive = isActive
        
        // Use PersistenceController's save method
        PersistenceController.shared.saveIfNeeded()
        print("✅ Context saved successfully")
        geofenceListViewModel.fetchGeofences()
    }
    
    var isValidGeofence: Bool {
        !name.isEmpty && latitude != 0
    }
}


