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
    @State private var showError = false
    @State private var currentError: AppError?
    
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
    
    private func setupBackgroundTasks() {
        // Start monitoring existing geofences
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        if let geofences = try? viewContext.fetch(fetchRequest) {
            for geofence in geofences where geofence.isActive {
                locationManager.startMonitoringGeofence(geofence)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            GeofenceListView(viewContext: viewContext)
                .environmentObject(locationManager)
                .alert(isPresented: $showError) {
                    Alert(
                        title: Text("Error"),
                        message: Text(currentError?.errorDescription ?? "An unknown error occurred"),
                        dismissButton: .default(Text("OK"), action: {
                            if case .permissionError = currentError {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        })
                    )
                }
        }
        .onAppear {
            checkLocationPermissions()
            locationManager.requestLocation()
            setupBackgroundTasks()
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
            // We're good to go
            setupBackgroundTasks()
        @unknown default:
            currentError = .unknownError
            showError = true
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
