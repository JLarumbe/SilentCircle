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
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        self.fetchRequest = NSFetchRequest<Geofence>(entityName: "Geofence")
        self.fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Geofence.name, ascending: true)]
        self.fetchRequest.fetchBatchSize = 20
        
        // Perform initial fetch synchronously to avoid state updates
        do {
            self.geofences = try viewContext.fetch(fetchRequest)
            print("✅ Initial fetch: \(self.geofences.count) geofences")
        } catch {
            print("❌ Error in initial fetch: \(error)")
        }
    }
    
    func fetchGeofences() async {
        // Skip if this is too soon after the last fetch
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            return
        }
        
        do {
            let newGeofences = try await viewContext.perform {
                try self.fetchRequest.execute()
            }
            
            // Only update if the geofences have actually changed
            if !geofencesAreEqual(newGeofences, geofences) {
                self.geofences = newGeofences
                lastFetchTime = Date()
                if !isInitialFetch {
                    print("✅ Fetched \(self.geofences.count) geofences")
                }
            }
            isInitialFetch = false
        } catch {
            print("❌ Error fetching geofences: \(error)")
        }
    }
    
    private func geofencesAreEqual(_ first: [Geofence], _ second: [Geofence]) -> Bool {
        guard first.count == second.count else { return false }
        return zip(first, second).allSatisfy { $0.objectID == $1.objectID }
    }
    
    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        // Setup Core Data observation with increased debounce
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .filter { notification in
                let context = notification.object as? NSManagedObjectContext
                return context == self.viewContext
            }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
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
                locationManager.stopMonitoringGeofence(geofence)
                viewContext.delete(geofence)
            }
            
            PersistenceController.shared.saveIfNeeded()
            await fetchGeofences()
        }
    }
    
    func stopObserving() {
        isObserving = false
        cancellables.removeAll()
    }
} 
