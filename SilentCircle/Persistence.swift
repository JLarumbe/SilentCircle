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
    // Change from private(set) back to regular static
    static let shared = PersistenceController()
    
    // Restore these properties
    private var cancellables = Set<AnyCancellable>()
    private let saveSubject = PassthroughSubject<Void, Never>()
    
    // Keep preview instance for SwiftUI previews only
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Sample geofence data only for previews
        let geofences = [
            ("Home", 40.7127, -73.9653, 50.0),
            ("Work", 40.7589, -73.9851, 100.0),
            ("Gym", 40.7486, -73.9840, 30.0),
            ("Coffee Shop", 40.7281, -73.9942, 25.0)
        ]
        
        // Create preview geofences
        for (name, lat, lon, radius) in geofences {
            let newGeofence = Geofence(context: viewContext)
            newGeofence.id = UUID()
            newGeofence.name = name
            newGeofence.latitude = lat
            newGeofence.longitude = lon
            newGeofence.radius = radius
            newGeofence.isActive = true
        }
        
        try? viewContext.save()
        return result
    }()

    private let inMemory: Bool
    
    // The NSPersistentContainer handles the Core Data stack including
    // the managed object model, persistent store coordinator, and context
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SilentCircle")
        
        if inMemory {
            // Use in-memory store for previews
            let storeDescription = NSPersistentStoreDescription()
            storeDescription.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
            
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
        self.inMemory = inMemory
        setupObservers()
        setupSavePublisher()
    }
    
    // Helper method to create a new background context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // Remove automatic saving and provide explicit save methods
    
    func saveIfNeeded() {
        saveSubject.send()
    }
    
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        
        do {
            try container.viewContext.save()
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
    
    private func setupSavePublisher() {
        saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    #if DEBUG
        func deleteAllData() {
            let context = container.viewContext
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Geofence")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try container.persistentStoreCoordinator.execute(deleteRequest, with: context)
            } catch {
                print("Error deleting all data: \(error)")
            }
        }
    #endif
}
