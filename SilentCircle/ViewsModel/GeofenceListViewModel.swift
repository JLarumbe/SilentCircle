import CoreData
import SwiftUI
import Combine

@MainActor
class GeofenceListViewModel: ObservableObject {
    @Published private(set) var geofences: [Geofence] = []
    @Published private(set) var isLoading = false
    @Published var selectedGeofence: Geofence?
    private let viewContext: NSManagedObjectContext
    private var fetchRequest: NSFetchRequest<Geofence>
    private var cancellables = Set<AnyCancellable>()
    private var isObserving = false
    private var lastFetchTime: Date?
    private let minimumFetchInterval: TimeInterval = 1.0
    private var isInitialFetch = true
    private let id = UUID()
    weak var locationManager: LocationManager?
    
    init(viewContext: NSManagedObjectContext, locationManager: LocationManager? = nil) {
        #if DEBUG
        print("\n📦 DEBUG: GeofenceListViewModel init")
        print("📍 DEBUG: ViewModel ID: \(UUID())")
        if let locationManager = locationManager {
            print("🔄 DEBUG: LocationManager: \(ObjectIdentifier(locationManager))")
        } else {
            print("🔄 DEBUG: LocationManager: nil")
        }
        #endif
        
        self.viewContext = viewContext
        self.locationManager = locationManager
        self.fetchRequest = NSFetchRequest<Geofence>(entityName: "Geofence")
        self.fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Geofence.name, ascending: true)]
        self.fetchRequest.fetchBatchSize = 20
        
        // Perform initial fetch synchronously to avoid state updates
        do {
            self.geofences = try viewContext.fetch(fetchRequest)
            print("✅ DEBUG: Initial fetch: \(self.geofences.count) geofences")
        } catch {
            print("❌ DEBUG: Error in initial fetch: \(error)")
        }
        
        #if DEBUG
        print("✅ DEBUG: GeofenceListViewModel init complete")
        #endif
    }
    
    func fetchGeofences() async {
        // Skip if this is too soon after the last fetch
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < minimumFetchInterval,
           !isInitialFetch {
            #if DEBUG
            print("\n⏱️ DEBUG: Skipping fetch - too soon")
            print("📍 DEBUG: ViewModel ID: \(id)")
            #endif
            return
        }
        
        do {
            let newGeofences = try await viewContext.perform {
                try self.fetchRequest.execute()
            }
            
            // Only update if the geofences have actually changed
            if !geofencesAreEqual(newGeofences, geofences) {
                #if DEBUG
                print("\n🔄 DEBUG: Updating geofences")
                print("📍 DEBUG: ViewModel ID: \(id)")
                print("📊 DEBUG: Old count: \(self.geofences.count)")
                print("📊 DEBUG: New count: \(newGeofences.count)")
                #endif
                
                self.geofences = newGeofences
                lastFetchTime = Date()
                if !isInitialFetch {
                    print("✅ DEBUG: Fetched \(self.geofences.count) geofences")
                }
            } else {
                #if DEBUG
                print("\n✨ DEBUG: No changes in geofences")
                print("📍 DEBUG: ViewModel ID: \(id)")
                #endif
            }
            isInitialFetch = false
        } catch {
            print("❌ DEBUG: Error fetching geofences: \(error)")
        }
    }
    
    private func geofencesAreEqual(_ first: [Geofence], _ second: [Geofence]) -> Bool {
        guard first.count == second.count else { return false }
        return zip(first, second).allSatisfy { $0.objectID == $1.objectID }
    }
    
    func startObserving() {
        guard !isObserving else {
            #if DEBUG
            print("\n⚠️ DEBUG: Already observing changes")
            print("📍 DEBUG: ViewModel ID: \(id)")
            #endif
            return
        }
        
        #if DEBUG
        print("\n👀 DEBUG: Starting observation")
        print("📍 DEBUG: ViewModel ID: \(id)")
        #endif
        
        isObserving = true
        
        // Setup Core Data observation with increased debounce
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .filter { notification in
                let context = notification.object as? NSManagedObjectContext
                return context == self.viewContext
            }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                #if DEBUG
                if let self = self {
                    print("\n💾 DEBUG: Core Data changes detected")
                    print("📍 DEBUG: ViewModel ID: \(self.id)")
                }
                #endif
                
                Task { [weak self] in
                    await self?.fetchGeofences()
                }
            }
            .store(in: &cancellables)
    }
    
    func deleteItems(at offsets: [Int], locationManager: LocationManager) {
        Task {
            for index in offsets {
                let geofence = geofences[index]
                await locationManager.stopMonitoringGeofence(geofence)
                viewContext.delete(geofence)
            }
            
            PersistenceController.shared.saveIfNeeded()
            await fetchGeofences()
        }
    }
    
    func deleteGeofence(_ geofence: Geofence, locationManager: LocationManager) {
        print("\n🗑️ DEBUG: Starting deleteGeofence")
        print("📍 DEBUG: Geofence: \(geofence.name ?? "Unnamed")")
        print("📍 DEBUG: Geofence ID: \(geofence.id?.uuidString ?? "nil")")
        
        Task {
            print("✅ DEBUG: Stopping monitoring for geofence")
            await locationManager.stopMonitoringGeofence(geofence)
            
            print("✅ DEBUG: Deleting geofence from context")
            viewContext.delete(geofence)
            
            print("✅ DEBUG: Saving context")
            PersistenceController.shared.saveIfNeeded()
            
            print("✅ DEBUG: Fetching updated geofences")
            await fetchGeofences()
            print("✅ DEBUG: Delete operation complete\n")
        }
    }
    
    func stopObserving() {
        #if DEBUG
        print("\n🛑 DEBUG: Stopping observation")
        print("📍 DEBUG: ViewModel ID: \(id)")
        #endif
        
        isObserving = false
        cancellables.removeAll()
    }
} 
