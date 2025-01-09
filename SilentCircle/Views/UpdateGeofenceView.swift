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
    @State private var cardOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var is3DEnabled = false
    @State private var mapPosition: MapCameraPosition
    @State private var isNavigationActive = true
    private let geofence: Geofence
    @StateObject private var keyboardManager = KeyboardManager()
    
    // Add keyboard handling
    @State private var keyboardCancellable: AnyCancellable?
    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
                .map { notification -> CGFloat in
                    (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        ).eraseToAnyPublisher()
    }
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext, geofence: Geofence) {
        self.geofence = geofence
        _viewModel = StateObject(wrappedValue: UpdateGeofenceViewModel(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext,
            geofence: geofence
        ))
        
        // Initialize map with existing geofence location
        _mapPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            distance: 500,
            heading: 0,
            pitch: 0
        )))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                MapContentView(
                    mapPosition: $mapPosition,
                    pinCoordinate: viewModel.pinCoordinate,
                    radius: viewModel.radius,
                    onTapLocation: { coordinate in
                        viewModel.handleMapTap(coordinate: coordinate)
                    },
                    onLocationRequest: requestLocation
                )
                .frame(height: geometry.size.height * 0.45)
                
                // Control Panel - exactly 50% height
                VStack(spacing: 20) {
                    HStack {
                        Text("Update Silent Circle")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        
                        Button(action: {
                            print("🔵 Button pressed")
                            if viewModel.isValidGeofence {
                                print("🟢 Geofence is valid")
                                updateGeofence()
                            } else {
                                print("🔴 Geofence is invalid")
                                print("Name empty: \(!viewModel.name.isEmpty)")
                                print("Latitude zero: \(viewModel.latitude == 0)")
                            }
                        }) {
                            Text("Update")
                                .font(.headline)
                                .foregroundStyle(viewModel.isValidGeofence ? .blue : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        .disabled(!viewModel.isValidGeofence)
                    }
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            TextField("Location Nickname", text: $viewModel.name)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .focused($isFocused)
                                .animation(.easeOut(duration: 0.2), value: isFocused)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "location.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.system(size: 28))
                                        .foregroundStyle(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(viewModel.latitude == 0 ? "Move map to set location" : "Location selected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: { 
                                    isFocused = false
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                                 to: nil, 
                                                                 from: nil, 
                                                                 for: nil)
                                    showingLocationSearch = true 
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 15, weight: .medium))
                                        Text("Search")
                                            .font(.callout.weight(.medium))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(width: 96, height: 34)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue)
                                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Toggle(isOn: $viewModel.isActive) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(viewModel.isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: viewModel.isActive ? "bell.fill" : "bell.slash.fill")
                                            .symbolRenderingMode(.hierarchical)
                                            .font(.system(size: 28))
                                            .foregroundStyle(viewModel.isActive ? .green : .gray)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Silent Circle Status")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(viewModel.isActive ? "Active" : "Inactive")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Radius")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(viewModel.radius))m")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "circle.dotted")
                                        .foregroundStyle(.blue)
                                    Slider(value: $viewModel.radius, in: 10...500, step: 10)
                                        .tint(.blue)
                                    Image(systemName: "circle")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(20)
                .frame(height: geometry.size.height * 0.5)
                .background(Color(.systemBackground))
                .offset(y: isFocused ? -keyboardHeight : 0)
                .animation(.easeOut(duration: 0.3), value: isFocused)
                .animation(.easeOut(duration: 0.3), value: keyboardHeight)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .interactiveDismissDisabled()
        .onChange(of: isNavigationActive) { oldValue, newValue in
            if !newValue {
                Task {
                    await viewModel.geofenceListViewModel.fetchGeofences()
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal)
                .padding(.top, 8)
                .opacity(isFocused ? 0 : 1)
                .animation(.easeInOut, value: isFocused)
            }
        }
        .onReceive(keyboardManager.$keyboardHeight) { height in
            self.keyboardHeight = height
        }
        .onAppear {
            // Initialize view model data
            viewModel.name = geofence.name ?? ""
            viewModel.radius = geofence.radius
            viewModel.latitude = geofence.latitude
            viewModel.longitude = geofence.longitude
            viewModel.isActive = geofence.isActive
            
            // Set up keyboard observation
            keyboardCancellable = try? keyboardPublisher.sink { height in
                Task { @MainActor in
                    withAnimation(.easeOut(duration: 0.3)) {
                        keyboardHeight = height
                    }
                }
            }
        }
        .onDisappear {
            viewModel.cleanup()
            // Clean up keyboard observation
            keyboardCancellable?.cancel()
        }
        .sheet(isPresented: $showingLocationSearch) {
            LocationSearchView(onLocationSelected: { name, coordinate in
                mapPosition = .camera(MapCamera(
                    centerCoordinate: coordinate,
                    distance: 1000,
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
                            distance: 1000,
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
    
    private func waitForLocation() async -> CLLocation? {
        for _ in 0..<3 { // Reduced attempts
            if let location = locationManager.userLocation {
                return location
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second intervals
        }
        return nil
    }
    
    private func updateMapPosition(with location: CLLocation) {
        mapPosition = .camera(MapCamera(
            centerCoordinate: location.coordinate,
            distance: 1000,
            heading: 0,
            pitch: 0
        ))
        viewModel.updateLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
    
    private func updateGeofence() {
        Task {
            print("\n🔄 DEBUG: Updating geofence")
            print("📍 DEBUG: New location: (\(viewModel.latitude), \(viewModel.longitude))")
            
            // Stop monitoring the old geofence
            locationManager.stopMonitoringGeofence(geofence)
            
            // Update the geofence properties
            geofence.name = viewModel.name
            geofence.latitude = viewModel.latitude
            geofence.longitude = viewModel.longitude
            geofence.radius = viewModel.radius
            geofence.isActive = viewModel.isActive
            
            // Save changes
            PersistenceController.shared.saveIfNeeded()
            
            // Start monitoring the updated geofence
            if geofence.isActive {
                locationManager.startMonitoringGeofence(geofence)
            }
            
            // Dismiss the view
            dismiss()
        }
    }
    
    private func convertToCoordinate(_ point: CGPoint, in geometry: GeometryProxy) -> CLLocationCoordinate2D? {
        let region = viewModel.getCurrentRegion()
        
        let mapFrame = geometry.frame(in: .local)
        
        // Convert point to normalized coordinates (0-1)
        let normalizedPoint = CGPoint(
            x: point.x / mapFrame.width,
            y: point.y / mapFrame.height
        )
        
        // Convert to map coordinates
        let span = region.span
        let center = region.center
        
        let latitude = center.latitude + (0.5 - normalizedPoint.y) * span.latitudeDelta
        let longitude = center.longitude + (normalizedPoint.x - 0.5) * span.longitudeDelta
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    private func extractCamera() -> MapCamera? {
        if let camera = try? mapPosition.camera {
            return camera
        }
        return nil
    }
}

// Add timeout utility
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {}

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

