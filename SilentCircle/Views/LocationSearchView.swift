import SwiftUI
import MapKit
import Combine

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(.purple)
            Text(title)
                .font(.title2.weight(.bold))
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var viewModel = LocationSearchViewModel()
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    @State private var searchDebounceTask: Task<Void, Never>?
    
    var onLocationSelected: ((String, CLLocationCoordinate2D) -> Void)?
    
    init(onLocationSelected: ((String, CLLocationCoordinate2D) -> Void)? = nil) {
        self.onLocationSelected = onLocationSelected
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search for a location", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($isFocused)
                            .tint(.purple)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    
                    // Results or Empty State
                    if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                        EmptyStateView(
                            title: "No Results Found",
                            systemImage: "mappin.slash",
                            description: "Try searching for a different location or address"
                        )
                    } else if !searchText.isEmpty {
                        // Results List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.searchResults, id: \.self) { result in
                                    Button {
                                        viewModel.selectLocation(result) { name, coordinate in
                                            onLocationSelected?(name, coordinate)
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(result.subtitle)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemGroupedBackground))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    } else {
                        // Initial State
                        EmptyStateView(
                            title: "Find a Location",
                            systemImage: "location.magnifyingglass",
                            description: "Search for an address or place to set your Silent Circle"
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms debounce
                if !Task.isCancelled {
                    await MainActor.run {
                        viewModel.updateSearchFragment(newValue)
                    }
                }
            }
        }
        .onAppear {
            isFocused = true
            viewModel.updateLocationManager(locationManager)
        }
    }
}

#Preview {
    LocationSearchView { title, coordinate in
        print("Selected: \(title) at \(coordinate)")
    }
    .environmentObject(LocationManager())
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