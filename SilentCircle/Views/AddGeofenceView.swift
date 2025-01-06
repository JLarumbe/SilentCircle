//
//  AddGeofenceView.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import SwiftUI
import MapKit

struct AddGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GeofenceListViewModel
    
    @State private var name: String = ""
    @State private var radius: Double = 10.0
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingLocationSearch = false
    @State private var cardOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Map View with precise pin - exactly 50% height
                Map(coordinateRegion: $region, showsUserLocation: true)
                    .frame(height: geometry.size.height * 0.5)
                    .overlay {
                        // Radius Circle
                        Circle()
                            .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                            .background(
                                Circle()
                                    .fill(.blue.opacity(0.1))
                            )
                            .frame(width: radiusToPoints(), height: radiusToPoints())
                            .allowsHitTesting(false)
                        
                        // Precise location indicator
                        ZStack {
                            // Pin shadow for depth
                            Circle()
                                .fill(.black.opacity(0.1))
                                .frame(width: 5, height: 5)
                                .blur(radius: 1)
                                .offset(y: 8)
                            
                            // Main pin
                            VStack(spacing: 0) {
                                Image(systemName: "mappin.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color(.systemBlue))
                                
                                // Precise point indicator
                                Rectangle()
                                    .fill(Color(.systemBlue))
                                    .frame(width: 2, height: 6)
                            }
                            .offset(y: 0)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        // Current Location Button with system colors
                        Button(action: {}) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.systemBlue))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .shadow(color: Color(.systemFill), radius: 4, x: 0, y: 2)
                                )
                        }
                        .padding([.trailing, .bottom], 16)
                    }
                
                // Control Panel - exactly 50% height
                VStack(spacing: 20) {
                    // Header without close button
                    HStack {
                        Text("New Geofence")
                            .font(.title3.weight(.semibold))
                        Spacer()
                    }
                    
                    // Main Content in ScrollView
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Name Field
                            TextField("Location name", text: $name)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .focused($isFocused)
                            
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
                                    Text(latitude == 0 ? "Move map to set location" : "Location selected")
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
                            
                            // Create Button
                            Button(action: {
                                viewModel.addGeofence(
                                    name: name,
                                    latitude: latitude,
                                    longitude: longitude,
                                    radius: radius
                                )
                                dismiss()
                            }) {
                                Text("Create Geofence")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(name.isEmpty || latitude == 0 ? Color.gray.opacity(0.5) : Color.blue)
                                        )
                            }
                            .disabled(name.isEmpty || latitude == 0)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(20)
                .frame(height: geometry.size.height * 0.5)
                .background(Color(.systemBackground))
                .offset(y: isFocused ? -keyboardHeight : 0)
                .animation(.spring(response: 0.3, dampingFraction: 1), value: keyboardHeight)
            }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: 
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundStyle(.blue)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
        )
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
        .sheet(isPresented: $showingLocationSearch) {
            LocationSearchView { name, coordinate in
                region.center = coordinate
                latitude = coordinate.latitude
                longitude = coordinate.longitude
                showingLocationSearch = false  // Dismiss the sheet after selection
            }
        }
    }
    
    private func radiusToPoints() -> CGFloat {
        let metersPerPoint = region.span.longitudeDelta * 111000 / UIScreen.main.bounds.width
        return (radius * 2) / metersPerPoint
    }
}

#Preview {
    NavigationView {
        AddGeofenceView(viewModel: GeofenceListViewModel(viewContext: PersistenceController.preview.container.viewContext))
    }
}


