import SwiftUI
import MapKit
import Combine

// Create a dedicated annotation type
struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

class LocationSearchHelper: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    private let searchCompleter: MKLocalSearchCompleter
    
    override init() {
        self.searchCompleter = MKLocalSearchCompleter()
        super.init()
        self.searchCompleter.delegate = self
        self.searchCompleter.resultTypes = .address
    }
    
    func updateSearchFragment(_ fragment: String) {
        searchCompleter.queryFragment = fragment
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
    
    func getCoordinates(for result: MKLocalSearchCompletion, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else {
                completion(nil)
                return
            }
            completion(coordinate)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedLocation: String?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @StateObject private var searchHelper = LocationSearchHelper()
    @FocusState private var isFocused: Bool
    
    var onLocationSelected: ((String, CLLocationCoordinate2D) -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color - using system background for consistency
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar with refined styling
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 44, height: 44)
                        
                        TextField("Search for a location", text: $searchText)
                            .font(.body)
                            .textFieldStyle(.plain)
                            .frame(height: 44)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.none)
                            .submitLabel(.search)
                            .focused($isFocused)
                        
                        if !searchText.isEmpty {
                            Button(action: { 
                                withAnimation {
                                    searchText = "" 
                                    searchHelper.searchResults = []
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    
                    // Selected Location Map
                    if let coordinate = selectedCoordinate {
                        let annotation = MapLocation(coordinate: coordinate)
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )), annotationItems: [annotation]) { location in
                            MapMarker(coordinate: location.coordinate, tint: .accentColor)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                    }
                    
                    // Search Results with refined styling
                    if !searchHelper.searchResults.isEmpty && selectedLocation == nil {
                        List {
                            ForEach(searchHelper.searchResults, id: \.self) { result in
                                Button(action: {
                                    withAnimation {
                                        selectedLocation = result.title
                                        searchText = result.title
                                        searchHelper.searchResults = []
                                        
                                        searchHelper.getCoordinates(for: result) { coordinate in
                                            if let coordinate = coordinate {
                                                selectedCoordinate = coordinate
                                                onLocationSelected?(result.title, coordinate)
                                            }
                                        }
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(result.title)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(result.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color(.systemBackground))
                    } else if searchText.isEmpty {
                        EmptyStateView(
                            title: "Find a Location",
                            systemImage: "location.magnifyingglass",
                            description: "Search for an address or place name to add a geofence"
                        )
                        .padding(.top, 40)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: searchText) { newValue in
                if !newValue.isEmpty {
                    searchHelper.updateSearchFragment(newValue)
                } else {
                    searchHelper.searchResults = []
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LocationSearchView { name, coordinate in
            print("Selected location: \(name) at \(coordinate)")
        }
    }
}

// Alternative preview showing different states
struct LocationSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LocationSearchView { name, coordinate in
                print("Selected location: \(name) at \(coordinate)")
            }
        }
    }
} 
