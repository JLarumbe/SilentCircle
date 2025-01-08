import Foundation
import CoreData

actor GeofenceFetchManager {
    private var isFetching = false
    private var lastFetchTime: Date?
    private let minimumFetchInterval: TimeInterval = 1.0
    
    func fetchIfNeeded(_ block: @escaping () async throws -> Void) async {
        guard !isFetching else { return }
        
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            return
        }
        
        isFetching = true
        defer { 
            isFetching = false 
            lastFetchTime = Date()
        }
        
        try? await block()
    }
} 