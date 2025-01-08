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
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var viewModel: LocationSearchViewModel
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    @State private var searchDebounceTask: Task<Void, Never>?
    
    var onLocationSelected: ((String, CLLocationCoordinate2D) -> Void)?
    
    init(onLocationSelected: ((String, CLLocationCoordinate2D) -> Void)? = nil) {
        self.onLocationSelected = onLocationSelected
        let tempLocationManager = LocationManager()
        _viewModel = StateObject(wrappedValue: LocationSearchViewModel(locationManager: tempLocationManager))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.searchResults.isEmpty && searchText.isEmpty {
                    EmptyStateView(
                        title: "Search Location",
                        systemImage: "magnifyingglass",
                        description: "Enter an address or place name to search"
                    )
                } else {
                    List(viewModel.searchResults, id: \.self) { result in
                        Button {
                            viewModel.selectLocation(result) { title, coordinate in
                                if let onLocationSelected = onLocationSelected {
                                    onLocationSelected(title, coordinate)
                                }
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(result.title)
                                    .font(.headline)
                                Text(result.subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .focused($isFocused)
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
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
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