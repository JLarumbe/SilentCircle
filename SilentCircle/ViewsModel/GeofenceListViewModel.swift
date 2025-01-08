import CoreData
import SwiftUI
import Combine

@MainActor
class GeofenceListViewModel: ObservableObject {
    @Published private(set) var geofences: [Geofence] = []
    @Published private(set) var isLoading = false
    let id = UUID().uuidString
    private let viewContext: NSManagedObjectContext
    private var fetchRequest: NSFetchRequest<Geofence>
    private var cancellables = Set<AnyCancellable>()
    private var isObserving = false
    
    private var fetchPublisher: AnyPublisher<[Geofence], Error> {
        Future { [weak self] promise in
            guard let self = self else { return }
            Task {
                do {
                    let geofences = try await self.viewContext.perform {
                        try self.fetchRequest.execute()
                    }
                    promise(.success(geofences))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    private var fetchCancellable: AnyCancellable?
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        // Setup fetch request once
        self.fetchRequest = NSFetchRequest<Geofence>(entityName: "Geofence")
        self.fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Geofence.name, ascending: true)]
        // Optional: Add batch size for large datasets
        self.fetchRequest.fetchBatchSize = 20
        
        Task {
            await fetchGeofences()
        }
    }
    
    func fetchGeofences() async {
        do {
            self.geofences = try await viewContext.perform {
                try self.fetchRequest.execute()
            }
            print("✅ Fetched \(self.geofences.count) geofences")
        } catch {
            print("❌ Error fetching geofences: \(error)")
        }
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
    
    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        // Clear existing subscriptions
        cancellables.removeAll()
        
        let publisher = Publishers.Merge(
            NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave),
            NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        
        publisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isLoading = true
                
                // Cancel previous fetch if any
                self.fetchCancellable?.cancel()
                
                self.fetchCancellable = self.fetchPublisher
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { [weak self] _ in
                            self?.isLoading = false
                        },
                        receiveValue: { [weak self] geofences in
                            self?.geofences = geofences
                        }
                    )
            }
            .store(in: &cancellables)
    }
    
    func stopObserving() {
        isObserving = false
        cancellables.removeAll()
        fetchCancellable?.cancel()
        fetchCancellable = nil
    }
    
    func updateGeofenceMonitoring(_ geofence: Geofence, locationManager: LocationManager) {
        // Always stop monitoring first to ensure clean state
        locationManager.stopMonitoringGeofence(geofence)
        
        if geofence.isActive {
            locationManager.startMonitoringGeofence(geofence)
        }
    }
} 
