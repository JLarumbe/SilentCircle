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


struct AddGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: AddGeofenceViewModel
    @State private var showingLocationSearch = false
    @State private var cardOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var is3DEnabled = false
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)  // ✅ More zoomed in (was 0.05)
    ))
    @State private var currentCoordinate: CLLocationCoordinate2D
    
    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
                .map { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0 },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    init(geofenceListViewModel: GeofenceListViewModel, viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: AddGeofenceViewModel(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext
        ))
        _currentCoordinate = State(initialValue: CLLocationCoordinate2D(
            latitude: 37.3346,
            longitude: -122.0090
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if #available(iOS 17.0, *) {
                    MapReader { proxy in
                        Map(position: $mapPosition) {
                            Marker("Silent Circle Location", coordinate: viewModel.pinCoordinate)
                                .tint(.blue)
                            
                            MapCircle(center: viewModel.pinCoordinate, radius: viewModel.radius)
                                .foregroundStyle(.blue.opacity(0.15))
                                .stroke(.blue.opacity(0.8), lineWidth: 1.5)
                        }
                        .onTapGesture { location in
                            if let coordinate = proxy.convert(location, from: .local) {
                                viewModel.handleMapTap(coordinate: coordinate)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .overlay(alignment: Alignment.bottomTrailing) {
                        VStack(spacing: 8) {
                            // Only keep the location button
                            Button(action: {
                                Task {
                                    viewModel.requestLocation()
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    
                                    await MainActor.run {
                                        if let location = viewModel.userLocation {
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
                } else {
                    // Fallback for earlier versions
                    Map(position: $mapPosition, interactionModes: .all) {
                        Marker("Silent Circle Location", coordinate: viewModel.pinCoordinate)
                            .tint(.blue)
                        
                        MapCircle(center: viewModel.pinCoordinate, radius: viewModel.radius)
                            .foregroundStyle(.blue.opacity(0.15))
                            .stroke(.blue.opacity(0.8), lineWidth: 1.5)
                    }
                    .overlay(alignment: Alignment.bottomTrailing) {
                        VStack(spacing: 8) {
                            // Only keep the location button
                            Button(action: {
                                Task {
                                    viewModel.requestLocation()
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    
                                    await MainActor.run {
                                        if let location = viewModel.userLocation {
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
                }
                
                // Control Panel - exactly 50% height
                VStack(spacing: 20) {
                    // Header without close button
                    HStack {
                        Text("New Silent Circle")
                            .font(.title3.weight(.semibold))
                        Spacer()
                    }
                    
                    // Main Content in ScrollView
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Name Field
                            TextField("Location Nickname", text: $viewModel.name)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .focused($isFocused)
                                .animation(.easeOut(duration: 0.2), value: isFocused)
                                .transaction { transaction in
                                    transaction.animation = .easeOut(duration: 0.2)
                                }
                            
                            // Location Info
                            HStack(spacing: 12) {
                                // Location Icon with Background
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "location.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.system(size: 28))
                                        .foregroundStyle(.blue)
                                }
                                
                                // Location Text
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(viewModel.latitude == 0 ? "Move map to set location" : "Location selected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // Search Button with Background
                                Button(action: { 
                                    isFocused = false  // Dismiss keyboard
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                                     to: nil, 
                                                                     from: nil, 
                                                                     for: nil)  // Force keyboard dismiss
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
                            
                            // Radius Control
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
                            
                            // Create Button
                            Button(action: {
                                Task {
                                    await viewModel.createGeofence()
                                    dismiss()
                                }
                            }) {
                                Text("Create Silent Circle")
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
                .transaction { transaction in
                    transaction.animation = .none
                }
                .onChange(of: isFocused || keyboardHeight > 0) { oldValue, newValue in
                    withAnimation(.easeOut(duration: 0.3)) {
                        cardOffset = newValue ? -keyboardHeight : 0
                    }
                }
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
                .opacity(isFocused ? 0 : 1)  // Hide back button when keyboard is shown
                .animation(.easeInOut, value: isFocused)
            }
        }
        .onAppear {
            viewModel.setupKeyboardObservers(publisher: keyboardPublisher) { height in
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = height
                }
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
    
    private func convertToCoordinate(_ point: CGPoint, in geometry: GeometryProxy) -> CLLocationCoordinate2D? {
        guard let region = viewModel.getCurrentRegion() else { return nil }
        
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
}

#Preview {
    let viewContext = PersistenceController.preview.container.viewContext
    let geofenceListViewModel = GeofenceListViewModel(viewContext: viewContext)
    
    return NavigationView {
        AddGeofenceView(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext
        )
    }
}


