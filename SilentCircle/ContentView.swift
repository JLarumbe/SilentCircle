//
//  ContentView.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import SwiftUI
import CoreData
import CoreLocation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    @StateObject private var geofenceListViewModel: GeofenceListViewModel
    @State private var showError = false
    @State private var currentError: AppError?
    private let id = UUID()
    
    init() {
        #if DEBUG
        print("\n🎯 DEBUG: ContentView init")
        print("📍 DEBUG: View ID: \(UUID())")
        #endif
        
        // Create LocationManager first
        let locationManager = LocationManager()
        
        #if DEBUG
        print("📱 DEBUG: Created LocationManager: \(ObjectIdentifier(locationManager))")
        #endif
        
        // Create ViewModel with LocationManager
        let viewModel = GeofenceListViewModel(
            viewContext: PersistenceController.shared.container.viewContext,
            locationManager: locationManager
        )
        
        #if DEBUG
        print("🔄 DEBUG: Created GeofenceListViewModel: \(ObjectIdentifier(viewModel))")
        #endif
        
        // Initialize state objects
        _locationManager = StateObject(wrappedValue: locationManager)
        _geofenceListViewModel = StateObject(wrappedValue: viewModel)
        
        #if DEBUG
        print("✅ DEBUG: ContentView init complete")
        #endif
    }
    
    // Define possible app errors
    enum AppError: Error, LocalizedError {
        case networkError
        case locationError
        case permissionError
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .networkError:
                return "Unable to connect to the network. Please check your connection and try again."
            case .locationError:
                return "Unable to access location services. Please check your location settings."
            case .permissionError:
                return "Silent Circle needs location permissions to function properly. Please enable them in Settings."
            case .unknownError:
                return "Something went wrong. Please try again."
            }
        }
    }
    
    var body: some View {
        GeofenceListView(viewModel: geofenceListViewModel)
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(locationManager)
            .alert(
                "Error",
                isPresented: $showError,
                presenting: currentError
            ) { error in
                Button("OK") {
                    if case .permissionError = error {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } message: { error in
                Text(error.localizedDescription)
            }
            .onAppear {
                #if DEBUG
                print("\n📱 DEBUG: ContentView appeared")
                print("📍 DEBUG: View ID: \(id)")
                print("🔄 DEBUG: Using GeofenceListViewModel: \(ObjectIdentifier(geofenceListViewModel))")
                #endif
            }
            // Add a stable identity to prevent unnecessary view recreation
            .id("root-geofence-list")
    }
    
    private func setupBackgroundTasks() async {
        print("\n🔄 DEBUG: Setting up background tasks")
        
        // Start monitoring existing geofences
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        if let geofences = try? viewContext.fetch(fetchRequest) {
            print("📍 DEBUG: Found \(geofences.count) geofences")
            
            // First, start monitoring all active geofences
            for geofence in geofences where geofence.isActive {
                locationManager.startMonitoringGeofence(geofence)
            }
            
            // Only request location if we don't have one
            if locationManager.userLocation == nil {
                print("⚠️ DEBUG: No location available yet, will check when location updates")
                locationManager.requestLocation()
            }
        }
    }
    
    private func checkLocationPermissions() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Wait for user response
            break
        case .restricted, .denied:
            currentError = .permissionError
            showError = true
        case .authorizedWhenInUse:
            // Prompt for Always authorization if needed
            locationManager.manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    // Helper function to handle errors
    private func handleError(_ error: AppError) {
        currentError = error
        showError = true
    }
}

// Preview configuration with sample Core Data
#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
