//
//  LocationSearchViewModel.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/6/25.
//
import SwiftUI
import MapKit
import Combine

struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

class LocationSearchViewModel: NSObject, ObservableObject {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var selectedLocation: String?
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    
    private let searchCompleter: MKLocalSearchCompleter
    private var currentSearch: MKLocalSearch?
    private var locationManager: LocationManager
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        self.searchCompleter = MKLocalSearchCompleter()
        super.init()
        self.searchCompleter.resultTypes = [.address, .pointOfInterest, .query]
        self.setupCompleter()
        
        if let userLocation = locationManager.userLocation {
            self.searchCompleter.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }
    
    private func setupCompleter() {
        searchCompleter.delegate = self
    }
    
    func updateSearchFragment(_ fragment: String) {
        if fragment.isEmpty {
            searchResults = []
        } else {
            searchCompleter.queryFragment = fragment
        }
    }
    
    func clearSearch() {
        searchResults = []
    }
    
    func selectLocation(_ result: MKLocalSearchCompletion, completion: @escaping (String, CLLocationCoordinate2D) -> Void) {
        // Cancel any existing search
        currentSearch?.cancel()
        
        selectedLocation = result.title
        
        // Create search request first
        let searchRequest = MKLocalSearch.Request(completion: result)
        currentSearch = MKLocalSearch(request: searchRequest)
        
        // Start the search with proper memory management
        currentSearch?.start { [weak self] response, error in
            guard let self = self,
                  let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.selectedCoordinate = coordinate
                completion(result.title, coordinate)
            }
        }
    }
    
    func updateLocationManager(_ newLocationManager: LocationManager) {
        self.locationManager = newLocationManager
        if let userLocation = newLocationManager.userLocation {
            self.searchCompleter.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }
}

// Add extension for MKLocalSearchCompleterDelegate
extension LocationSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchResults = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
}