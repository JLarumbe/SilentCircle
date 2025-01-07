//
//  Persistence.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import CoreData
import Combine

// PersistenceController manages the Core Data stack for the entire app
class PersistenceController {
    // Shared singleton instance that can be accessed throughout the app
    static let shared = PersistenceController()
    private var cancellables = Set<AnyCancellable>()

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
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SilentCircle")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
            // Configure the view context after loading
            let viewContext = container.viewContext
            viewContext.automaticallyMergesChangesFromParent = true
            viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        return container
    }()

    // Add property to track save state
    private var isSaving = false

    // Initialize the Core Data stack
    init(inMemory: Bool = false) {
        // For previews, use an in-memory store instead of writing to disk
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Optimized observer setup
        setupObservers()
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
        
        Task {
            await save(context: context)
        }
    }
    
    private func save(context: NSManagedObjectContext) async {
        guard !isSaving else { return }
        isSaving = true
        
        do {
            try await context.perform {
                try context.save()
            }
        } catch {
            print("❌ Error saving context: \(error)")
        }
        
        isSaving = false
    }
    
    // Optimized observer setup
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let context = notification.object as? NSManagedObjectContext,
                      context == self.container.viewContext else { return }
                
                self.saveIfNeeded()
            }
            .store(in: &cancellables)
    }
}
