import CoreData
import SwiftUI

class GeofenceListViewModel: ObservableObject {
    // Holds reference to Core Data context for database operations
    private var viewContext: NSManagedObjectContext
    
    // Published property that the View observes for changes
    // When this array updates, any View observing it will automatically refresh
    @Published var geofences: [Geofence] = []
    
    // Initialize with Core Data context and immediately fetch data
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        fetchGeofences()
    }
    
    // Fetches geofences from Core Data and updates the published array
    // This triggers a View refresh when completed
    func fetchGeofences() {
        let request = NSFetchRequest<Geofence>(entityName: "Geofence")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Geofence.name, ascending: true)]
        
        do {
            // Updates the @Published property, automatically notifying observers
            geofences = try viewContext.fetch(request)
        } catch {
            print("Error fetching geofences: \(error)")
        }
    }

    func addGeofence(name: String, latitude: Double, longitude: Double, radius: Double) {
        let newGeofence = Geofence(context: viewContext)
        newGeofence.id = UUID()
        newGeofence.name = name
        newGeofence.latitude = latitude
        newGeofence.longitude = longitude
        newGeofence.radius = radius
        newGeofence.isActive = true
        
        do {
            try viewContext.save()
            fetchGeofences()
        } catch {
            print("Error adding geofence: \(error)")
        }
    }
    
    // Called by the View when user performs a delete action
    func deleteItems(at offsets: IndexSet) {
        withAnimation {
            // Convert IndexSet to array of geofences and delete from Core Data
            offsets.map { geofences[$0] }.forEach(viewContext.delete)
            
            do {
                // Persist the deletion to Core Data
                try viewContext.save()
                // Refresh the published array to reflect changes
                fetchGeofences()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    func addSampleData() {
        let sampleGeofences = ("Test", 37.7749, -122.4194, 100.0, true)
        
        addGeofence(name: sampleGeofences.0, 
                    latitude: sampleGeofences.1, 
                    longitude: sampleGeofences.2, 
                    radius: sampleGeofences.3)
    }
} 
