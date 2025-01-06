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
    
    override init() {
        self.searchCompleter = MKLocalSearchCompleter()
        super.init()
        self.searchCompleter.resultTypes = .address
        self.setupCompleter()
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
        selectedLocation = result.title
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            
            DispatchQueue.main.async {
                self.selectedCoordinate = coordinate
                completion(result.title, coordinate)
            }
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