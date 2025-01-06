import SwiftUI
import MapKit
import Combine

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
    @StateObject private var viewModel: LocationSearchViewModel
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    @State private var searchDebounceTask: Task<Void, Never>?
    
    var onLocationSelected: ((String, CLLocationCoordinate2D) -> Void)?
    
    init(onLocationSelected: ((String, CLLocationCoordinate2D) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: LocationSearchViewModel())
        self.onLocationSelected = onLocationSelected
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar
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
                                    viewModel.clearSearch()
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
                    if let coordinate = viewModel.selectedCoordinate {
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
                    
                    // Search Results
                    if !viewModel.searchResults.isEmpty && viewModel.selectedLocation == nil {
                        List {
                            ForEach(viewModel.searchResults, id: \.self) { result in
                                Button(action: {
                                    withAnimation {
                                        searchText = result.title
                                        viewModel.selectLocation(result) { name, coordinate in
                                            onLocationSelected?(name, coordinate)
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
                // Cancel any existing debounce task
                searchDebounceTask?.cancel()
                
                // Create new debounce task
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    if !Task.isCancelled {
                        await MainActor.run {
                            viewModel.updateSearchFragment(newValue)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LocationSearchView()
    }
}

// Alternative preview showing different states
struct LocationSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LocationSearchView(onLocationSelected: { name, coordinate in
                print("Selected location: \(name) at \(coordinate)")
            })
        }
    }
}