import SwiftUI
import CoreData
import MapKit

struct GeofenceListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: GeofenceListViewModel
    
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
                List {
                    ForEach(viewModel.geofences) { geofence in
                        GeofenceRow(
                            geofence: geofence,
                            geofenceListViewModel: viewModel,
                            needsRefresh: .constant(false)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.deleteItems(at: [viewModel.geofences.firstIndex(of: geofence)!])
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Silent Circles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: AddGeofenceView(
                    geofenceListViewModel: viewModel,
                    viewContext: viewContext
                )) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            print("💾 Context did save - refreshing data")
            viewContext.refreshAllObjects()
            viewModel.fetchGeofences()
        }
    }
}

struct GeofenceRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var geofence: Geofence
    let geofenceListViewModel: GeofenceListViewModel
    @Binding var needsRefresh: Bool
    
    var body: some View {
        NavigationLink(destination: UpdateGeofenceView(
            geofenceListViewModel: geofenceListViewModel,
            viewContext: viewContext,
            geofence: geofence
        )) {
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
