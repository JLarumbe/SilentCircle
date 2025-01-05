import SwiftUI
import CoreData

struct GeofenceListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: GeofenceListViewModel
    
    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: GeofenceListViewModel(viewContext: viewContext))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.geofences) { geofence in
                GeofenceRow(geofence: geofence)
            }
            .onDelete { offsets in
                viewModel.deleteItems(at: offsets)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: viewModel.addSampleData) {
                    Label("Add Geofence", systemImage: "plus")
                }
            }
        }
    }
}

struct GeofenceRow: View {
    let geofence: Geofence
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(geofence.name ?? "Unnamed Location")
                .font(.headline)
            Text("Radius: \(Int(geofence.radius))m")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
} 
