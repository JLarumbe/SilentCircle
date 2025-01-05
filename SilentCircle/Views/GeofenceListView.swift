import SwiftUI
import CoreData
import MapKit

struct GeofenceListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: GeofenceListViewModel
    
    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: GeofenceListViewModel(viewContext: viewContext))
    }
    
    var body: some View {
        ZStack {
            if viewModel.geofences.isEmpty {
                GeofenceEmptyStateView(
                    title: "No Geofences",
                    systemImage: "location.circle",
                    description: "Add your first geofence to get started"
                )
            } else {
                List {
                    ForEach(viewModel.geofences) { geofence in
                        GeofenceRow(geofence: geofence)
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
        .navigationTitle("Geofences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddGeofenceView(viewModel: viewModel)
                    .navigationBarBackButtonHidden(true)) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .refreshable {
            viewModel.fetchGeofences()
        }
    }
}

struct GeofenceRow: View {
    let geofence: Geofence
    
    var body: some View {
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
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
