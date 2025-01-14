//
//  AddGeofenceView.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//
import SwiftUI
import MapKit
import CoreData
import Combine

@MainActor
class MapCameraState: ObservableObject {
    @Published var camera: MapCamera
    
    init(coordinate: CLLocationCoordinate2D, radius: Double) {
        self.camera = MapCamera(
            centerCoordinate: coordinate,
            distance: max(radius * 2, 250),
            heading: 0,
            pitch: 0
        )
    }
    
    func update(coordinate: CLLocationCoordinate2D? = nil, radius: Double) {
        withAnimation {
            camera = MapCamera(
                centerCoordinate: coordinate ?? camera.centerCoordinate,
                distance: max(radius * 2, 250),
                heading: camera.heading,
                pitch: camera.pitch
            )
        }
    }
}

struct AddGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var viewModel: AddGeofenceViewModel
    @State private var mapPosition: MapCameraPosition
    @State private var showingLocationSearch = false
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var currentStep = 0
    @State private var keyboardCancellable: AnyCancellable?
    @State private var viewID = UUID()
    @State private var isSettingLocation = false
    
    private let steps = ["Name", "Location", "Radius"]
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext) {
        print("🏗️ DEBUG: AddGeofenceView init")
        _viewModel = StateObject(wrappedValue: AddGeofenceViewModel(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext
        ))
        _mapPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
            distance: 250,
            heading: 0,
            pitch: 0
        )))
    }
    
    var body: some View {
        GeometryReader { geometry in
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
                    onFinish: {
                        Task {
                            await viewModel.createGeofence()
                            dismiss()
                        }
                    }
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
        }
        .background(Color(.systemBackground))
        .onAppear {
            print("📱 DEBUG: AddGeofenceView appeared - ID: \(viewID)")
        }
        .onDisappear {
            print("🚫 DEBUG: AddGeofenceView disappeared - ID: \(viewID)")
        }
        .onChange(of: locationManager.monitoringStatus) { oldValue, newValue in
            print("�� DEBUG: AddGeofenceView - Monitoring status changed")
            print("  - View ID: \(viewID)")
            print("  - Old value: \(oldValue)")
            print("  - New value: \(newValue)")
            print("  - Current step: \(currentStep)")
            print("  - Is setting location: \(isSettingLocation)")
        }
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !viewModel.name.isEmpty
        case 1: return viewModel.latitude != 0 && viewModel.longitude != 0
        case 2: return true
        default: return false
        }
    }
    
    private func requestLocation() {
        print("\n📍 DEBUG: AddGeofenceView - Requesting location")
        print("  - View ID: \(viewID)")
        print("  - Current step: \(currentStep)")
        
        isSettingLocation = true
        
        Task {
            // Request a single location update
            locationManager.requestLocation()
            
            // Wait for location with timeout
            for attempt in 0..<10 {
                print("  - Location attempt: \(attempt + 1)")
                if let location = locationManager.userLocation {
                    await MainActor.run {
                        print("  - Location received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                        // Update the map camera and view model with the new location
                        // Use a smaller initial radius for a more zoomed in view
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
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            }
            
            // Small delay to ensure location processing is complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
            isSettingLocation = false
            print("  - Location request completed")
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
                .padding(.top, 8)
            
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
        .padding(.vertical, 8)
    }
}

private struct LocationStepView: View {
    @ObservedObject var viewModel: AddGeofenceViewModel
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
            .padding(.top, 8)
            
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
    @ObservedObject var viewModel: AddGeofenceViewModel
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
            .padding(.top, 8)
            
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
                Text(currentStep < totalSteps - 1 ? "Next" : "Create Circle")
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
    
    return NavigationView {
        AddGeofenceView(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext
        )
        .environmentObject(locationManager)
    }
}


