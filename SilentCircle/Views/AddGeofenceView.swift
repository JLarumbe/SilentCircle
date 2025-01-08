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

struct ControlPanelHeaderView: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
        }
    }
}

struct LocationNameFieldView: View {
    @Binding var name: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        TextField("Location Nickname", text: $name)
            .textFieldStyle(.plain)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .focused($isFocused)
    }
}

struct LocationInfoView: View {
    @ObservedObject var viewModel: AddGeofenceViewModel
    @Binding var showingLocationSearch: Bool
    
    var body: some View {
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
            
            Button(action: { 
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
    }
}

struct RadiusControlView: View {
    @Binding var radius: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Radius")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(radius))m")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.blue)
                Slider(value: $radius, in: 10...500, step: 10)
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

struct CreateButtonView: View {
    let isValidGeofence: Bool
    let onCreate: () -> Void
    
    var body: some View {
        Button(action: onCreate) {
            Text("Create Silent Circle")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isValidGeofence ? Color.blue : Color.gray.opacity(0.5))
                )
        }
        .disabled(!isValidGeofence)
        .padding(.top, 8)
    }
}

struct AddGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var viewModel: AddGeofenceViewModel
    @State private var showingLocationSearch = false
    @State private var cardOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var is3DEnabled = false
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))
    @State private var currentCoordinate: CLLocationCoordinate2D
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
                    ControlPanelHeaderView(title: "New Silent Circle")
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            LocationNameFieldView(name: $viewModel.name, isFocused: $isFocused)
                            LocationInfoView(viewModel: viewModel, showingLocationSearch: $showingLocationSearch)
                            RadiusControlView(radius: $viewModel.radius)
                            CreateButtonView(
                                isValidGeofence: viewModel.isValidGeofence,
                                onCreate: {
                                    Task {
                                        await viewModel.createGeofence()
                                        dismiss()
                                    }
                                }
                            )
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
                .opacity(isFocused ? 0 : 1)
                .animation(.easeInOut, value: isFocused)
            }
        }
        .onAppear {
            // Set up keyboard observation
            keyboardCancellable = keyboardPublisher.sink { height in
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = height
                }
            }
        }
        .onDisappear {
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
    let locationManager = LocationManager()
    
    return NavigationView {
        AddGeofenceView(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext
        )
        .environmentObject(locationManager)
    }
}


