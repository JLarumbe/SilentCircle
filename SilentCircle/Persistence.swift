//
//  Persistence.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import CoreData

// PersistenceController manages the Core Data stack for the entire app
struct PersistenceController {
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
        
        // Automatically merge changes from parent contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
