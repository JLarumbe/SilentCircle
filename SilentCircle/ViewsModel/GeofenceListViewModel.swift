import CoreData
import SwiftUI

@MainActor
class GeofenceListViewModel: ObservableObject {
    @Published private(set) var geofences: [Geofence] = []
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        fetchGeofences()
    }
    
    func fetchGeofences() {
        let request = NSFetchRequest<Geofence>(entityName: "Geofence")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Geofence.name, ascending: true)]
        
        do {
            self.geofences = try viewContext.fetch(request)
            print("✅ Fetched \(geofences.count) geofences")
        } catch {
            print("❌ Error fetching geofences: \(error)")
        }
    }
    
    func deleteItems(at offsets: [Int]) {
        for index in offsets {
            viewContext.delete(geofences[index])
        }
        
        do {
            try viewContext.save()
            fetchGeofences()
        } catch {
            print("Error deleting geofence: \(error)")
        }
    }
} 
