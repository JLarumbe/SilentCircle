//
//  UpdateGeofenceView.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/6/25.
//

import SwiftUI
import MapKit
import CoreData
import Combine

struct UpdateGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var viewModel: UpdateGeofenceViewModel
    @State private var showingLocationSearch = false
    @FocusState private var isFocused: Bool
    @State private var currentStep = 0
    @State private var mapPosition: MapCameraPosition
    @State private var lastCameraDistance: Double = 250  // Store last camera distance
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.kilometers.rawValue
    private let geofence: Geofence
    
    private let steps = ["Name", "Location", "Radius", "Settings"]
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext, geofence: Geofence) {
        self.geofence = geofence
        _viewModel = StateObject(wrappedValue: UpdateGeofenceViewModel(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext,
            geofence: geofence
        ))
        
        _mapPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            distance: max(geofence.radius * 2, 250),
            heading: 0,
            pitch: 0
        )))
    }
    
    // Helper function to update map camera while preserving zoom
    private func updateMapCamera(coordinate: CLLocationCoordinate2D) {
        if let camera = try? mapPosition.camera {
            mapPosition = .camera(MapCamera(
                centerCoordinate: coordinate,
                distance: camera.distance,
                heading: camera.heading,
                pitch: camera.pitch
            ))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Progress Header
                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.purple : Color(.systemGray4))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Tab Navigation
                HStack(spacing: 0) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Button(action: {
                            withAnimation {
                                currentStep = index
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(steps[index])
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(currentStep == index ? .purple : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                // Active Indicator
                                Capsule()
                                    .fill(currentStep == index ? Color.purple : Color.clear)
                                    .frame(height: 3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            
            // Main Content
            Group {
                switch currentStep {
                case 0:
                    NameStepView(
                        name: $viewModel.name,
                        isFocused: $isFocused
                    )
                case 1:
                    LocationStepView(
                        viewModel: viewModel,
                        mapPosition: $mapPosition,
                        showingLocationSearch: $showingLocationSearch,
                        onLocationRequest: requestLocation
                    )
                case 2:
                    RadiusStepView(
                        radius: $viewModel.radius,
                        mapPosition: $mapPosition,
                        distanceUnit: distanceUnit,
                        pinCoordinate: viewModel.pinCoordinate
                    )
                case 3:
                    SettingsStepView(
                        isActive: $viewModel.isActive
                    )
                default:
                    EmptyView()
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .padding(.top, 16)
            
            Spacer()
            
            // Save Button
            Button(action: updateGeofence) {
                HStack(spacing: 8) {
                    Text("Save Changes")
                        .font(.headline)
                    Image(systemName: "checkmark.circle.fill")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isCurrentStepValid ? Color.purple : Color.gray.opacity(0.5))
                )
            }
            .disabled(!isCurrentStepValid)
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                }
            }
        }
        .sheet(isPresented: $showingLocationSearch) {
            LocationSearchView(onLocationSelected: { name, coordinate in
                mapPosition = .camera(MapCamera(
                    centerCoordinate: coordinate,
                    distance: max(viewModel.radius * 2, 250),
                    heading: 0,
                    pitch: 0
                ))
                viewModel.updateLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                showingLocationSearch = false
            })
        }
        .onAppear {
            // Initialize view model data
            viewModel.name = geofence.name ?? ""
            viewModel.radius = geofence.radius
            viewModel.latitude = geofence.latitude
            viewModel.longitude = geofence.longitude
            viewModel.isActive = geofence.isActive
        }
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !viewModel.name.isEmpty
        case 1: return viewModel.latitude != 0 && viewModel.longitude != 0
        case 2: return true
        case 3: return true
        default: return false
        }
    }
    
    private func requestLocation() {
        Task {
            print("📍 Requesting current location")
            locationManager.requestLocation()
            
            // Wait for location update with timeout
            for _ in 0..<10 {  // Try for 5 seconds
                if let location = locationManager.userLocation {
                    print("✅ Got location: \(location.coordinate)")
                    await MainActor.run {
                        mapPosition = .camera(MapCamera(
                            centerCoordinate: location.coordinate,
                            distance: max(viewModel.radius * 2, 250),
                            heading: 0,
                            pitch: 0
                        ))
                        viewModel.updateLocation(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                    }
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    private func updateGeofence() {
        Task {
            print("\n🔄 DEBUG: Updating geofence")
            print("📍 DEBUG: New location: (\(viewModel.latitude), \(viewModel.longitude))")
            
            // Update the geofence properties
            geofence.name = viewModel.name
            geofence.latitude = viewModel.latitude
            geofence.longitude = viewModel.longitude
            geofence.radius = viewModel.radius
            geofence.isActive = viewModel.isActive
            
            // Save changes
            PersistenceController.shared.saveIfNeeded()
            
            // Update monitoring
            Task {
                if geofence.isActive {
                    await locationManager.updateGeofence(geofence)
                } else {
                    await locationManager.stopMonitoringGeofence(geofence)
                }
                
                // Dismiss the view
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Step Views

private struct NameStepView: View {
    @Binding var name: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("What would you like to call this Silent Circle?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("e.g. Home, Work, Library", text: $name)
                .textFieldStyle(.plain)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal)
                .focused($isFocused)
        }
    }
}

private struct LocationStepView: View {
    @ObservedObject var viewModel: UpdateGeofenceViewModel
    @Binding var mapPosition: MapCameraPosition
    @Binding var showingLocationSearch: Bool
    let onLocationRequest: () -> Void
    
    private func handleMapTap(coordinate: CLLocationCoordinate2D) {
        viewModel.handleMapTap(coordinate: coordinate)
        if let camera = try? mapPosition.camera {
            mapPosition = .camera(MapCamera(
                centerCoordinate: coordinate,
                distance: camera.distance,
                heading: camera.heading,
                pitch: camera.pitch
            ))
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: { showingLocationSearch = true }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.purple)
                    Text("Search for a location")
                        .foregroundStyle(.purple)
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple, lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            MapContentView(
                mapPosition: $mapPosition,
                pinCoordinate: viewModel.pinCoordinate,
                radius: viewModel.radius,
                onTapLocation: handleMapTap,
                onLocationRequest: onLocationRequest
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
}

private struct RadiusStepView: View {
    @Binding var radius: Double
    @Binding var mapPosition: MapCameraPosition
    let distanceUnit: String
    let pinCoordinate: CLLocationCoordinate2D
    
    var body: some View {
        VStack(spacing: 24) {
            MapContentView(
                mapPosition: $mapPosition,
                pinCoordinate: pinCoordinate,
                radius: radius,
                onTapLocation: { _ in },
                onLocationRequest: { },
                showLocationButton: false
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.top, 8)
            .gesture(MagnificationGesture().onChanged { _ in }) // Disable zooming
            .gesture(DragGesture().onChanged { _ in }) // Disable panning
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Circle Radius")
                        .font(.headline)
                    Spacer()
                    Text(CLLocationDistance(radius).formatted(unit: DistanceUnit(rawValue: distanceUnit) ?? .kilometers))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                        )
                }
                
                HStack {
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(.purple)
                    Slider(value: $radius, 
                           in: distanceUnit == DistanceUnit.kilometers.rawValue ? 10...500 : 11...547, // 10-500m or equivalent in yards
                           step: distanceUnit == DistanceUnit.kilometers.rawValue ? 10 : 11) { editing in
                        if !editing {
                            updateMapCamera()
                        }
                    }
                    .tint(.purple)
                    Image(systemName: "circle")
                        .foregroundStyle(.purple)
                }
                
                Text("This circle will cover approximately a \(radiusDescription) area")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    private var radiusDescription: String {
        if radius < 50 {
            return "small"
        } else if radius < 200 {
            return "medium"
        } else {
            return "large"
        }
    }
    
    private func updateMapCamera() {
        mapPosition = .camera(MapCamera(
            centerCoordinate: pinCoordinate,
            distance: max(radius * 2, 250),
            heading: 0,
            pitch: 0
        ))
    }
}

private struct SettingsStepView: View {
    @Binding var isActive: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Would you like to start monitoring this Silent Circle?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Toggle(isOn: $isActive) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isActive ? Color.purple.opacity(0.15) : Color.gray.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: isActive ? "bell.fill" : "bell.slash.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 18))
                            .foregroundStyle(isActive ? .purple : .gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monitoring")
                            .font(.subheadline.weight(.medium))
                        Text(isActive ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.purple)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Supporting Views

private struct ProgressHeader: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.purple : Color(.systemGray4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct NavigationButtons: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let isStepValid: Bool
    let onFinish: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: { withAnimation { currentStep -= 1 } }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple, lineWidth: 1)
                    )
                }
            }
            
            Button(action: {
                withAnimation {
                    if currentStep < totalSteps - 1 {
                        currentStep += 1
                    } else {
                        onFinish()
                    }
                }
            }) {
                Text(currentStep < totalSteps - 1 ? "Next" : "Save Changes")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isStepValid ? Color.purple : Color.gray.opacity(0.5))
                    )
            }
            .disabled(!isStepValid)
        }
    }
}

#Preview {
    let viewContext = PersistenceController.preview.container.viewContext
    let geofenceListViewModel = GeofenceListViewModel(viewContext: viewContext)
    let locationManager = LocationManager()
    
    // Create a sample geofence for preview
    let geofence = Geofence(context: viewContext)
    geofence.id = UUID()
    geofence.name = "Test Location"
    geofence.latitude = 37.3346
    geofence.longitude = -122.0090
    geofence.radius = 100
    geofence.isActive = true
    
    return NavigationView {
        UpdateGeofenceView(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext,
            geofence: geofence
        )
        .environmentObject(locationManager)
    }
}

