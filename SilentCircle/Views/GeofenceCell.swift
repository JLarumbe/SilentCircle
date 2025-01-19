import SwiftUI
import CoreLocation

struct GeofenceCell: View {
    // MARK: - Properties
    @ObservedObject var geofence: Geofence
    let isActive: Bool
    let onTap: (Geofence) -> Void
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var locationManager: LocationManager
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.kilometers.rawValue
    
    // MARK: - Computed Properties
    private var distanceFromUser: String? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let geofenceLocation = CLLocation(latitude: geofence.latitude, longitude: geofence.longitude)
        let distance = geofenceLocation.distance(from: userLocation)
        let unit = DistanceUnit(rawValue: distanceUnit) ?? .kilometers
        return distance.formatted(unit: unit)
    }
    
    private var statusColor: Color {
        if isActive {
            return .purple
        } else if geofence.isActive {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if isActive {
            return "Currently Inside"
        } else if geofence.isActive {
            return "Monitoring"
        } else {
            return "Not Monitoring"
        }
    }
    
    private var radiusText: String {
        let unit = DistanceUnit(rawValue: distanceUnit) ?? .kilometers
        return CLLocationDistance(geofence.radius).formatted(unit: unit)
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: { onTap(geofence) }) {
            VStack(spacing: 0) {
                // Main Content
                HStack(alignment: .center, spacing: 16) {
                    // Status Icon Column
                    VStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        
                        Rectangle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: 2)
                    }
                    .frame(height: 50)
                    .padding(.leading, 4)
                    
                    // Info Column
                    VStack(alignment: .leading, spacing: 6) {
                        // Title Row
                        Text(geofence.name ?? "Unnamed Circle")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        // Status Row
                        HStack(spacing: 12) {
                            // Status Badge
                            Text(statusText)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(statusColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(statusColor.opacity(0.15))
                                )
                            
                            // Distance Badge (if available)
                            if let distance = distanceFromUser {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                    Text(distance)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.tertiarySystemFill))
                                )
                            }
                        }
                    }
                    
                    Spacer(minLength: 16)
                    
                    // Right Column
                    VStack(alignment: .trailing, spacing: 6) {
                        // Radius Badge
                        HStack(spacing: 4) {
                            Image(systemName: "ruler.fill")
                                .font(.caption2)
                            Text(radiusText)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                        )
                        
                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Bottom Divider
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.leading, 44)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                           radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(geofence.name ?? "Unnamed Circle"), \(statusText), \(radiusText)")
        .accessibilityHint("Double tap to edit this Silent Circle")
    }
}

// MARK: - Preview
#Preview {
    let viewContext = PersistenceController.preview.container.viewContext
    let geofence = Geofence(context: viewContext)
    geofence.id = UUID()
    geofence.name = "Home"
    geofence.latitude = 37.7749
    geofence.longitude = -122.4194
    geofence.radius = 100
    geofence.isActive = true
    
    return VStack(spacing: 16) {
        // Active and Inside
        GeofenceCell(
            geofence: geofence,
            isActive: true,
            onTap: { _ in }
        )
        
        // Active but Outside
        GeofenceCell(
            geofence: geofence,
            isActive: false,
            onTap: { _ in }
        )
        
        // Inactive
        GeofenceCell(
            geofence: {
                let g = geofence
                g.isActive = false
                return g
            }(),
            isActive: false,
            onTap: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .environmentObject(LocationManager())
} 