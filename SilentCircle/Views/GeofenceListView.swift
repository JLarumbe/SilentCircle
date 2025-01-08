import SwiftUI
import CoreData
import MapKit
import Combine

struct GeofenceListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: GeofenceListViewModel
    let locationManager: LocationManager
    
    init(viewModel: GeofenceListViewModel, locationManager: LocationManager) {
        print("🏁 GeofenceListView init")
        _viewModel = StateObject(wrappedValue: viewModel)
        self.locationManager = locationManager
    }
    
    var body: some View {
        NavigationStack {
            GeofenceListMainView(
                viewModel: viewModel,
                locationManager: locationManager,
                viewContext: viewContext
            )
        }
    }
}

private struct GeofenceListMainView: View {
    @ObservedObject var viewModel: GeofenceListViewModel
    let locationManager: LocationManager
    let viewContext: NSManagedObjectContext
    
    var body: some View {
        ZStack {
            if viewModel.geofences.isEmpty {
                GeofenceEmptyStateView(
                    title: "No Silent Circles",
                    systemImage: "location.circle",
                    description: "Add your first Silent Circle to get started"
                )
            } else {
                GeofenceListContent(
                    viewModel: viewModel,
                    locationManager: locationManager
                )
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
        .onAppear {
            print("📱 GeofenceListView appeared")
            viewModel.startObserving()
            // Start monitoring existing active geofences
            Task {
                // Delay the geofence monitoring setup slightly
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay
                for geofence in viewModel.geofences where geofence.isActive {
                    locationManager.startMonitoringGeofence(geofence)
                }
            }
        }
        .onDisappear {
            print("👋 GeofenceListView disappeared")
            viewModel.stopObserving()
        }
        .navigationDestination(item: $viewModel.selectedGeofence) { geofence in
            UpdateGeofenceView(
                geofenceListViewModel: viewModel,
                viewContext: viewContext,
                geofence: geofence
            )
            .environmentObject(locationManager)
        }
    }
}

// Extracted to a separate view to improve performance
private struct GeofenceListContent: View {
    @ObservedObject var viewModel: GeofenceListViewModel
    let locationManager: LocationManager
    
    init(viewModel: GeofenceListViewModel, locationManager: LocationManager) {
        print("📋 GeofenceListContent init")
        self.viewModel = viewModel
        self.locationManager = locationManager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bars
            StatusBarView()
                .environmentObject(locationManager)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            List {
                ForEach(viewModel.geofences) { geofence in
                    GeofenceCell(
                        geofence: geofence,
                        geofenceListViewModel: viewModel,
                        locationManager: locationManager,
                        needsRefresh: .constant(false)
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
                    .onChange(of: geofence.isActive) { _, _ in
                        if geofence.isActive {
                            locationManager.startMonitoringGeofence(geofence)
                        } else {
                            locationManager.stopMonitoringGeofence(geofence)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct GeofenceCell: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var geofence: Geofence
    let geofenceListViewModel: GeofenceListViewModel
    let locationManager: LocationManager
    @Binding var needsRefresh: Bool
    
    var body: some View {
        Button {
            geofenceListViewModel.selectedGeofence = geofence
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

#Preview {
    let viewContext = PersistenceController.preview.container.viewContext
    let geofenceListViewModel = GeofenceListViewModel(viewContext: viewContext)
    let locationManager = LocationManager()
    
    return NavigationView {
        GeofenceListView(
            viewModel: geofenceListViewModel,
            locationManager: locationManager
        )
    }
}
