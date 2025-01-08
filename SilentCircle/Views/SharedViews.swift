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
    
    var body: some View {
        if #available(iOS 17.0, *) {
            MapReader { proxy in
                Map(position: $mapPosition) {
                    Marker("Silent Circle Location", coordinate: pinCoordinate)
                        .tint(.blue)
                    
                    MapCircle(center: pinCoordinate, radius: radius)
                        .foregroundStyle(.blue.opacity(0.15))
                        .stroke(.blue.opacity(0.8), lineWidth: 1.5)
                }
                .onTapGesture { location in
                    if let coordinate = proxy.convert(location, from: .local) {
                        onTapLocation(coordinate)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .overlay(alignment: .bottomTrailing) {
                LocationButtonView(onLocationRequest: onLocationRequest)
            }
        } else {
            Map(position: $mapPosition) {
                Marker("Silent Circle Location", coordinate: pinCoordinate)
                    .tint(.blue)
                
                MapCircle(center: pinCoordinate, radius: radius)
                    .foregroundStyle(.blue.opacity(0.15))
                    .stroke(.blue.opacity(0.8), lineWidth: 1.5)
            }
            .overlay(alignment: .bottomTrailing) {
                LocationButtonView(onLocationRequest: onLocationRequest)
            }
        }
    }
} 