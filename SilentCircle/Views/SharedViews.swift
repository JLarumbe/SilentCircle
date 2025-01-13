import SwiftUI
import MapKit

struct LocationButtonView: View {
    let onLocationRequest: () -> Void
    
    var body: some View {
        Button(action: onLocationRequest) {
            Image(systemName: "location.fill")
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.thinMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .padding()
    }
}

struct MapContentView: View {
    @Binding var mapPosition: MapCameraPosition
    let pinCoordinate: CLLocationCoordinate2D
    let radius: Double
    let onTapLocation: (CLLocationCoordinate2D) -> Void
    let onLocationRequest: () -> Void
    let showLocationButton: Bool
    
    init(mapPosition: Binding<MapCameraPosition>,
         pinCoordinate: CLLocationCoordinate2D,
         radius: Double,
         onTapLocation: @escaping (CLLocationCoordinate2D) -> Void,
         onLocationRequest: @escaping () -> Void,
         showLocationButton: Bool = true) {
        _mapPosition = mapPosition
        self.pinCoordinate = pinCoordinate
        self.radius = radius
        self.onTapLocation = onTapLocation
        self.onLocationRequest = onLocationRequest
        self.showLocationButton = showLocationButton
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            MapReader { proxy in
                Map(position: $mapPosition) {
                    Marker("Silent Circle Location", coordinate: pinCoordinate)
                        .tint(.purple)
                    
                    MapCircle(center: pinCoordinate, radius: radius)
                        .foregroundStyle(.purple.opacity(0.15))
                        .stroke(.purple.opacity(0.8), lineWidth: 1.5)
                }
                .onTapGesture { location in
                    if let coordinate = proxy.convert(location, from: .local) {
                        onTapLocation(coordinate)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Map showing Silent Circle location")
            .accessibilityHint("Tap anywhere on the map to set the Silent Circle location. A marker shows the center location and a circle shows the boundary with \(Int(radius)) meters radius.")
            .overlay(alignment: .bottomTrailing) {
                if showLocationButton {
                    LocationButtonView(onLocationRequest: onLocationRequest)
                        .accessibilityLabel("Use current location")
                        .accessibilityHint("Double tap to center the map on your current location")
                }
            }
        } else {
            Map(position: $mapPosition) {
                Marker("Silent Circle Location", coordinate: pinCoordinate)
                    .tint(.purple)
                
                MapCircle(center: pinCoordinate, radius: radius)
                    .foregroundStyle(.purple.opacity(0.15))
                    .stroke(.purple.opacity(0.8), lineWidth: 1.5)
            }
            .overlay(alignment: .bottomTrailing) {
                if showLocationButton {
                    LocationButtonView(onLocationRequest: onLocationRequest)
                }
            }
        }
    }
} 