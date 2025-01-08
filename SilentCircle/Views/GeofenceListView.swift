import SwiftUI
import CoreData
import MapKit
import Combine

struct GeofenceListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: GeofenceListViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @State private var selectedGeofence: Geofence?
    @State private var showingAddGeofence = false
    
    init(viewContext: NSManagedObjectContext) {
        print("🏁 GeofenceListView init")
        _viewModel = StateObject(wrappedValue: GeofenceListViewModel(viewContext: viewContext))
    }
    
    var body: some View {
        ZStack {
            if viewModel.geofences.isEmpty {
                GeofenceEmptyStateView(
                    title: "No Silent Circles",
                    systemImage: "location.circle",
                    description: "Add your first Silent Circle to get started"
                )
            } else {
                VStack(spacing: 0) {
                    // Status Bar with improved design
                    if !viewModel.geofences.isEmpty {
                        VStack(spacing: 12) {
                            // Location Status Group
                            StatusGroup(
                                icon: locationStatusIcon,
                                iconColor: locationStatusColor,
                                title: "Location",
                                status: locationStatusText
                            )
                            
                            // Monitoring Status Group
                            StatusGroup(
                                icon: monitoringStatusIcon,
                                iconColor: monitoringStatusColor,
                                title: "Monitoring",
                                status: monitoringStatusText
                            )
                            
                            // Active Circle Status - Only show when inside a geofence
                            if let name = activeGeofenceName {
                                StatusGroup(
                                    icon: "checkmark.shield.fill",
                                    iconColor: .green,
                                    title: "Active Circle",
                                    status: name,
                                    background: Color.green.opacity(0.1)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    }
                    
                    List {
                        ForEach(viewModel.geofences) { geofence in
                            GeofenceRow(
                                geofence: geofence,
                                geofenceListViewModel: viewModel,
                                needsRefresh: .constant(false),
                                selectedGeofence: $selectedGeofence
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.deleteItems(
                                            at: [viewModel.geofences.firstIndex(of: geofence)!],
                                            locationManager: locationManager
                                        )
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onChange(of: geofence.isActive) { _, newValue in
                                viewModel.updateGeofenceMonitoring(geofence, locationManager: locationManager)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle("Silent Circles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    AddGeofenceView(
                        geofenceListViewModel: viewModel,
                        viewContext: viewContext
                    )
                    .environmentObject(locationManager)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .id(viewModel.id)
        .onAppear {
            print("📱 GeofenceListView appeared [\(viewModel.id)]")
            viewModel.startObserving()
            // Start monitoring existing active geofences
            for geofence in viewModel.geofences where geofence.isActive {
                locationManager.startMonitoringGeofence(geofence)
            }
        }
        .onDisappear {
            print("👋 GeofenceListView disappeared [\(viewModel.id)]")
            viewModel.stopObserving()
        }
        .navigationDestination(item: $selectedGeofence) { geofence in
            UpdateGeofenceView(
                geofenceListViewModel: viewModel,
                viewContext: viewContext,
                geofence: geofence
            )
            .environmentObject(locationManager)
        }
    }
    
    // Location Status
    private var locationStatusIcon: String {
        switch locationManager.monitoringStatus {
        case .ready, .noGeofences:
            return "location.fill"
        case .noLocation, .notAuthorized:
            return "location.slash.fill"
        case .unknown:
            return "location.circle"
        }
    }
    
    private var locationStatusColor: Color {
        switch locationManager.monitoringStatus {
        case .ready, .noGeofences:
            return .green
        case .noLocation:
            return .orange
        case .notAuthorized:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var locationStatusText: String {
        switch locationManager.monitoringStatus {
        case .ready, .noGeofences:
            return "Available"
        case .noLocation:
            return "Disabled"
        case .notAuthorized:
            return "Not Authorized"
        case .unknown:
            return "Checking..."
        }
    }
    
    // Monitoring Status
    private var monitoringStatusIcon: String {
        switch locationManager.monitoringStatus {
        case .ready:
            return "checkmark.circle.fill"
        case .noGeofences:
            return "mappin.slash.circle.fill"
        case .noLocation:
            return "exclamationmark.triangle.fill"
        case .notAuthorized:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "ellipsis.circle.fill"
        }
    }
    
    private var monitoringStatusColor: Color {
        switch locationManager.monitoringStatus {
        case .ready:
            return .green
        case .noGeofences:
            return .blue
        case .noLocation:
            return .orange
        case .notAuthorized:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var monitoringStatusText: String {
        switch locationManager.monitoringStatus {
        case .ready:
            return "Active"
        case .noGeofences:
            return "No Active Circles"
        case .noLocation:
            return "Location Required"
        case .notAuthorized:
            return "Permission Required"
        case .unknown:
            return "Checking..."
        }
    }
    
    // Add this to observe currentGeofence changes
    private var activeGeofenceName: String? {
        locationManager.currentGeofence?.name
    }
    
    private func statusView(for geofence: Geofence) -> some View {
        HStack {
            let isActive = geofence.name == activeGeofenceName
            let icon = isActive ? "checkmark.circle.fill" : "circle"
            let iconColor: Color = isActive ? .green : .secondary
            let status = isActive ? "Active" : "Inactive"
            
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            
            Text(status)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? .green : .secondary)
        }
    }
}

struct GeofenceRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var geofence: Geofence
    let geofenceListViewModel: GeofenceListViewModel
    @Binding var needsRefresh: Bool
    @EnvironmentObject private var locationManager: LocationManager
    @Binding var selectedGeofence: Geofence?
    
    var body: some View {
        Button {
            selectedGeofence = geofence
        } label: {
            HStack(spacing: 16) {
                // Location Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "location.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
                
                // Location Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(geofence.name ?? "Unnamed Location")
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        // Radius Badge
                        HStack(spacing: 4) {
                            Image(systemName: "circle.dashed")
                                .font(.subheadline)
                            Text("\(Int(geofence.radius))m")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                        
                        // Status Badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(geofence.isActive ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(geofence.isActive ? "Active" : "Inactive")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .id(geofence.objectID)
    }
}

struct GeofenceEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 64))
                    .foregroundStyle(.blue.opacity(0.8))
                    .padding(.bottom, 8)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Status Group Component
struct StatusGroup: View {
    let icon: String
    let iconColor: Color
    let title: String
    let status: String
    var background: Color = .clear
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32) // Following 44pt minimum touch target
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            // Status Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(status)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(background)
        .cornerRadius(12)
    }
}
