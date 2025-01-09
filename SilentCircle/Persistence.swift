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
            // Use in-memory store for previewss
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

    // Background context for heavy operations
    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    // Initialize the Core Data stack
    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        
        if inMemory {
            print("💾 DEBUG: Initializing in-memory Core Data stack")
        } else {
            print("💾 DEBUG: Initializing persistent Core Data stack")
        }
        
        setupObservers()
        setupSavePublisher()
        print("✅ DEBUG: Core Data stack initialization complete")
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
        guard !isSaving else {
            print("⏳ DEBUG: Save already in progress, skipping")
            return
        }
        
        print("💾 DEBUG: Starting context save operation")
        isSaving = true
        
        do {
            try container.viewContext.save()
            print("✅ DEBUG: Successfully saved view context")
        } catch {
            print("❌ DEBUG: Failed to save view context")
            print("❌ DEBUG: Error: \(error.localizedDescription)")
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
    
    // MARK: - Background Operations
    
    /// Perform a task in the background context
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await backgroundContext.perform {
            try block(self.backgroundContext)
        }
    }
    
    /// Save changes in the background context
    func saveBackgroundContext() async throws {
        try await backgroundContext.perform {
            guard self.backgroundContext.hasChanges else {
                print("ℹ️ DEBUG: No changes in background context to save")
                return
            }
            
            print("💾 DEBUG: Saving background context changes")
            try self.backgroundContext.save()
            print("✅ DEBUG: Successfully saved background context")
        }
    }
    
    // MARK: - Batch Operations
    
    /// Perform a batch update operation
    func batchUpdate(
        entityName: String,
        propertiesToUpdate: [AnyHashable: Any]
    ) async throws {
        print("\n🔄 DEBUG: Starting batch update operation")
        print("📝 DEBUG: Entity: \(entityName)")
        print("🔧 DEBUG: Properties to update: \(propertiesToUpdate)")
        
        let request = NSBatchUpdateRequest(entityName: entityName)
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = .updatedObjectIDsResultType
        
        try await performBackgroundTask { context in
            let result = try context.execute(request) as? NSBatchUpdateResult
            let changes = [NSUpdatedObjectIDsKey: result?.result as? [NSManagedObjectID] ?? []]
            
            print("🔄 DEBUG: Merging changes to view context")
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [self.container.viewContext]
            )
            
            print("✅ DEBUG: Successfully completed batch update")
            if let count = (result?.result as? [NSManagedObjectID])?.count {
                print("📊 DEBUG: Updated \(count) objects")
            }
        }
    }
    
    /// Perform a batch delete operation
    func batchDelete(
        fetchRequest: NSFetchRequest<NSFetchRequestResult>
    ) async throws {
        print("\n🗑️ DEBUG: Starting batch delete operation")
        
        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        request.resultType = .resultTypeObjectIDs
        
        try await performBackgroundTask { context in
            let result = try context.execute(request) as? NSBatchDeleteResult
            let changes = [NSDeletedObjectIDsKey: result?.result as? [NSManagedObjectID] ?? []]
            
            print("🔄 DEBUG: Merging changes to view context")
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [self.container.viewContext]
            )
            
            print("✅ DEBUG: Successfully completed batch delete")
            if let count = (result?.result as? [NSManagedObjectID])?.count {
                print("📊 DEBUG: Deleted \(count) objects")
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Fetch objects in background
    func fetchInBackground<T: NSManagedObject>(
        fetchRequest: NSFetchRequest<T>
    ) async throws -> [T] {
        print("\n🔍 DEBUG: Starting background fetch")
        print("📝 DEBUG: Entity: \(T.entity().name ?? "Unknown")")
        
        let results = try await performBackgroundTask { context in
            let results = try context.fetch(fetchRequest)
            print("✅ DEBUG: Successfully fetched \(results.count) objects")
            return results
        }
        
        return results
    }
    
    /// Create object in background
    func createInBackground<T: NSManagedObject>(
        _ entityType: T.Type,
        configure: @escaping (T) -> Void
    ) async throws {
        print("\n📝 DEBUG: Creating new object in background")
        print("📝 DEBUG: Entity: \(T.entity().name ?? "Unknown")")
        
        try await performBackgroundTask { context in
            let object = T(context: context)
            configure(object)
            
            print("💾 DEBUG: Saving new object")
            try context.save()
            print("✅ DEBUG: Successfully created and saved new object")
        }
    }
}
