import SwiftUI

struct GeofenceCell: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var geofence: Geofence
    let geofenceListViewModel: GeofenceListViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @Binding var needsRefresh: Bool
    
    var body: some View {
        Button {
            geofenceListViewModel.selectedGeofence = geofence
        } label: {
            HStack(spacing: 16) {
                // Location Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "location.circle.fill")
                        .font(.title)
                        .foregroundStyle(.purple)
                }
                
                // Location Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(geofence.name ?? "Unknown Location")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("\(Int(geofence.radius))m radius")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Active Toggle
                Toggle("", isOn: Binding(
                    get: { geofence.isActive },
                    set: { newValue in
                        geofence.isActive = newValue
                        try? viewContext.save()
                    }
                ))
                .labelsHidden()
                .tint(.purple)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
} 