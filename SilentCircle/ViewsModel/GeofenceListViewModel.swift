import CoreData
import SwiftUI

@MainActor
class GeofenceListViewModel: ObservableObject {
    @Published private(set) var geofences: [Geofence] = []
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        Task {
            await fetchGeofences()
        }
    }
    
    func fetchGeofences() async {
        let request = NSFetchRequest<Geofence>(entityName: "Geofence")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Geofence.name, ascending: true)]
        
        do {
            self.geofences = try await viewContext.perform {
                try request.execute()
            }
            print("✅ Fetched \(self.geofences.count) geofences")
        } catch {
            print("❌ Error fetching geofences: \(error)")
        }
    }
    
    func deleteItems(at offsets: [Int]) {
        Task {
            for index in offsets {
                viewContext.delete(geofences[index])
            }
            
            PersistenceController.shared.saveIfNeeded()
            await fetchGeofences()
        }
    }
} 
