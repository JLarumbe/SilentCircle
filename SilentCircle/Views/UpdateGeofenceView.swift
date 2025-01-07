//
//  UpdateGeofenceView.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/6/25.
//

import SwiftUI
import MapKit
import CoreData

struct UpdateGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: AddGeofenceViewModel
    @StateObject private var locationManager = LocationManager()
    let geofence: Geofence
    
    @State private var showingLocationSearch = false
    @State private var cardOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var is3DEnabled = false
    @State private var mapPosition: MapCameraPosition
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext, geofence: Geofence) {
        self.geofence = geofence
        _viewModel = StateObject(wrappedValue: AddGeofenceViewModel(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext
        ))
        
        // Initialize map position with existing geofence location
        _mapPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            distance: 1000,
            heading: 0,
            pitch: 0
        )))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Map View with precise pin - adjusted to 45% height
                Map(position: $mapPosition) {
                    let coordinate = mapPosition.camera?.centerCoordinate ?? CLLocationCoordinate2D(
                        latitude: viewModel.latitude,
                        longitude: viewModel.longitude
                    )
                    
                    Marker("Silent Circle Location", coordinate: coordinate)
                        .tint(.blue)
                    
                    MapCircle(center: coordinate, radius: viewModel.radius)
                        .foregroundStyle(.blue.opacity(0.15))
                        .stroke(.blue.opacity(0.8), lineWidth: 1.5)
                }
                .mapStyle(.standard(elevation: .realistic))
                .overlay(alignment: .bottomTrailing) {
                    VStack(spacing: 8) {
                        Button(action: {
                            Task {
                                locationManager.requestLocation()
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                
                                await MainActor.run {
                                    if let location = locationManager.userLocation {
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
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 40)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                    }
                    .padding()
                }
                .frame(height: geometry.size.height * 0.45)
                .onMapCameraChange(frequency: .continuous) { context in
                    viewModel.updateLocation(
                        latitude: context.camera.centerCoordinate.latitude,
                        longitude: context.camera.centerCoordinate.longitude
                    )
                }
                
                // Control Panel - exactly 50% height
                VStack(spacing: 20) {
                    HStack {
                        Text("Update Silent Circle")
                            .font(.title3.weight(.semibold))
                        Spacer()
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
                                Text("Update Silent Circle")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(viewModel.isValidGeofence ? Color.blue : Color.gray.opacity(0.5))
                                    )
                            }
                            .disabled(!viewModel.isValidGeofence)
                            .padding(.top, 8)
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
        .onAppear {
            // Pre-fill the form with existing geofence data
            viewModel.name = geofence.name ?? ""
            viewModel.radius = geofence.radius
            viewModel.latitude = geofence.latitude
            viewModel.longitude = geofence.longitude
            viewModel.isActive = geofence.isActive
            
            // Keyboard observers
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
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
    
    private func updateGeofence() {
        geofence.name = viewModel.name
        geofence.latitude = viewModel.latitude
        geofence.longitude = viewModel.longitude
        geofence.radius = viewModel.radius
        geofence.isActive = viewModel.isActive
        
        // Use PersistenceController's save method
        PersistenceController.shared.saveIfNeeded()
        print("✅ Context saved successfully")
        
        // Add this line to refresh the list
        viewModel.geofenceListViewModel.fetchGeofences()
        
        dismiss()
    }
}

#Preview {
    let viewContext = PersistenceController.preview.container.viewContext
    let geofenceListViewModel = GeofenceListViewModel(viewContext: viewContext)
    
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
    }
}

