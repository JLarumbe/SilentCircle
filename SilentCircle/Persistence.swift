//
//  Persistence.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import CoreData

// PersistenceController manages the Core Data stack for the entire app
class PersistenceController {
    // Shared singleton instance that can be accessed throughout the app
    static let shared = PersistenceController()

    // Creates a preview instance with sample data for SwiftUI previews
    // @MainActor ensures this runs on the main thread where UI updates happen
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Sample geofence data
        let geofences = [
            ("Home", 40.7127, -73.9653, 50.0),
            ("Work", 40.7589, -73.9851, 100.0),
            ("Gym", 40.7486, -73.9840, 30.0),
            ("Coffee Shop", 40.7281, -73.9942, 25.0)
        ]
        
        // Create multiple geofences
        for (name, lat, lon, radius) in geofences {
            let newGeofence = Geofence(context: viewContext)
            newGeofence.id = UUID()
            newGeofence.name = name
            newGeofence.latitude = lat
            newGeofence.longitude = lon
            newGeofence.radius = radius
            newGeofence.isActive = true
        }
        
        // Save the sample data to the preview context
        do {
            try viewContext.save()
        } catch {
            // Error handling for development purposes
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    // The NSPersistentContainer handles the Core Data stack including
    // the managed object model, persistent store coordinator, and context
    let container: NSPersistentContainer

    // Add property to track save state
    private var isSaving = false
    private var saveWorkItem: DispatchWorkItem?

    // Initialize the Core Data stack
    init(inMemory: Bool = false) {
        // Create container with our model name
        container = NSPersistentContainer(name: "SilentCircle")
        
        // For previews, use an in-memory store instead of writing to disk
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Load the persistent stores
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Common error cases:
                // - Directory permissions issues
                // - Device locked/data protection
                // - Insufficient storage
                // - Model version migration failures
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // Configure the view context
        let viewContext = container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Modified auto-save with better notification filtering
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: viewContext,  // Only observe this specific context
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  !self.isSaving,
                  let context = notification.object as? NSManagedObjectContext,
                  context == viewContext,
                  // Only save if there are actual changes, not during a save operation
                  let userInfo = notification.userInfo,
                  let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>,
                  let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
                  let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>,
                  (!inserts.isEmpty || !updates.isEmpty || !deletes.isEmpty)
            else { return }
            
            self.isSaving = true
            do {
                try viewContext.save()
            } catch {
                print("❌ Error auto-saving context: \(error)")
            }
            self.isSaving = false
        }
    }
    
    // Helper method to create a new background context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // Remove automatic saving and provide explicit save methods
    
    func saveIfNeeded() {
        let context = container.viewContext
        guard !isSaving, context.hasChanges else { return }
        
        isSaving = true
        do {
            try context.save()
        } catch {
            print("❌ Error saving context: \(error)")
        }
        isSaving = false
    }
}
