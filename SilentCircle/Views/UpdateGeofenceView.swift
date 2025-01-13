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
    
    var body: some View {
            VStack(spacing: 0) {
            // Progress Header
            ProgressHeader(currentStep: currentStep, totalSteps: steps.count)
                .padding(.top, 4)
            
            // Step Title
            Text(steps[currentStep])
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
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
                        viewModel: viewModel,
                        mapPosition: $mapPosition
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
                                
                                Spacer()
                                
            // Navigation Buttons
            NavigationButtons(
                currentStep: $currentStep,
                totalSteps: steps.count,
                isStepValid: isCurrentStepValid,
                onFinish: updateGeofence
            )
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
            if geofence.isActive {
                locationManager.updateGeofence(geofence)
            } else {
                locationManager.stopMonitoringGeofence(geofence)
            }
            
            // Dismiss the view
            dismiss()
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
            
            MapContentView(
                mapPosition: $mapPosition,
                pinCoordinate: viewModel.pinCoordinate,
                radius: viewModel.radius,
                onTapLocation: { coordinate in
                    viewModel.handleMapTap(coordinate: coordinate)
                    mapPosition = .camera(MapCamera(
                        centerCoordinate: coordinate,
                        distance: max(viewModel.radius * 2, 250),
                        heading: 0,
                        pitch: 0
                    ))
                },
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
    @ObservedObject var viewModel: UpdateGeofenceViewModel
    @Binding var mapPosition: MapCameraPosition
    
    var body: some View {
        VStack(spacing: 24) {
            MapContentView(
                mapPosition: $mapPosition,
                pinCoordinate: viewModel.pinCoordinate,
                radius: viewModel.radius,
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
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Circle Radius")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(viewModel.radius))m")
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
                    Slider(value: $viewModel.radius, in: 10...500, step: 10) { editing in
                        if !editing {
                            mapPosition = .camera(MapCamera(
                                centerCoordinate: viewModel.pinCoordinate,
                                distance: max(viewModel.radius * 2, 250),
                                heading: 0,
                                pitch: 0
                            ))
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
        if viewModel.radius < 50 {
            return "small"
        } else if viewModel.radius < 200 {
            return "medium"
        } else {
            return "large"
        }
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

