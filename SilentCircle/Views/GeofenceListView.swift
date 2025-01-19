import SwiftUI
import CoreData
import MapKit
import Combine
import CoreLocation

@MainActor
class GeofenceStateController: ObservableObject {
    private let viewModel: GeofenceListViewModel
    private let id = UUID()
    private var hasAppeared = false
    private var lastSignificantChange = Date()
    private var lastGeofenceCount: Int?
    private var lastMonitoringStatus: LocationManager.MonitoringStatus?
    private var lastActiveGeofence: String?
    private var isProcessingUpdate = false
    
    init(viewModel: GeofenceListViewModel) {
        self.viewModel = viewModel
        print("🎮 DEBUG: GeofenceStateController init")
        print("📍 DEBUG: Controller ID: \(id)")
        print("🔄 DEBUG: ViewModel: \(ObjectIdentifier(viewModel))")
        
        initializeState()
    }
    
    private func initializeState() {
        lastGeofenceCount = viewModel.geofences.count
        lastMonitoringStatus = viewModel.locationManager?.monitoringStatus
        lastActiveGeofence = viewModel.locationManager?.currentGeofence?.name
        
        print("📊 DEBUG: Initial state:")
        print("  - Geofence count: \(lastGeofenceCount ?? 0)")
        print("  - Monitoring status: \(String(describing: lastMonitoringStatus))")
        print("  - Active geofence: \(lastActiveGeofence ?? "none")")
    }
    
    func setup() {
        guard !hasAppeared else { return }
        hasAppeared = true
        
        print("🎯 DEBUG: GeofenceStateController setup")
        print("📍 DEBUG: Controller ID: \(id)")
        
        startObservingChanges()
    }
    
    private func startObservingChanges() {
        Task {
            let viewModelChanges = viewModel.objectWillChange
            let locationManagerChanges = viewModel.locationManager?.objectWillChange.eraseToAnyPublisher() ?? Empty<Void, Never>().eraseToAnyPublisher()
            
            for await _ in viewModelChanges.merge(with: locationManagerChanges).debounce(for: .milliseconds(100), scheduler: DispatchQueue.main).values {
                await processStateUpdate()
            }
        }
    }
    
    func processStateUpdate() async {
        guard !isProcessingUpdate else { return }
        isProcessingUpdate = true
        defer { isProcessingUpdate = false }
        
        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastSignificantChange)
        
        // Check for significant changes
        let currentGeofenceCount = viewModel.geofences.count
        let currentMonitoringStatus = viewModel.locationManager?.monitoringStatus
        let currentActiveGeofence = viewModel.locationManager?.currentGeofence?.name
        
        var hasSignificantChange = false
        
        if currentGeofenceCount != lastGeofenceCount {
            print("🔄 DEBUG: Geofence count changed from \(lastGeofenceCount ?? 0) to \(currentGeofenceCount)")
            hasSignificantChange = true
        }
        
        if currentMonitoringStatus != lastMonitoringStatus {
            print("🔄 DEBUG: Monitoring status changed from \(String(describing: lastMonitoringStatus)) to \(String(describing: currentMonitoringStatus))")
            hasSignificantChange = true
        }
        
        if currentActiveGeofence != lastActiveGeofence {
            print("🔄 DEBUG: Active geofence changed from \(lastActiveGeofence ?? "nil") to \(currentActiveGeofence ?? "nil")")
            hasSignificantChange = true
        }
        
        if hasSignificantChange && timeSinceLastChange >= 0.5 {
            print("🔄 DEBUG: Processing state update")
            print("📍 DEBUG: Controller ID: \(id)")
            
            lastGeofenceCount = currentGeofenceCount
            lastMonitoringStatus = currentMonitoringStatus
            lastActiveGeofence = currentActiveGeofence
            lastSignificantChange = now
            objectWillChange.send()
        } else {
            print("ℹ️ DEBUG: Skipping update - no significant changes or too soon")
        }
    }
}

struct GeofenceListView: View {
    @StateObject private var stateController: GeofenceStateController
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.managedObjectContext) private var viewContext
    private let id = UUID()
    @ObservedObject var viewModel: GeofenceListViewModel
    @State private var showingAddGeofence = false
    @State private var showingSettings = false
    
    init(viewModel: GeofenceListViewModel) {
        self.viewModel = viewModel
        print("🏁 DEBUG: GeofenceListView init")
        print("📍 DEBUG: View ID: \(id)")
        print("🔄 DEBUG: ViewModel: \(ObjectIdentifier(viewModel))")
        print("📱 DEBUG: Parent View: \(Thread.callStackSymbols[0])")
        _stateController = StateObject(wrappedValue: GeofenceStateController(viewModel: viewModel))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.geofences.isEmpty {
                    ListEmptyStateView(showAddSheet: $showingAddGeofence)
                } else {
                    GeofenceListContent(
                        viewModel: viewModel
                    )
                }
            }
            .navigationTitle("Silent Circles")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAddGeofence) {
                NavigationView {
                    AddGeofenceView(
                        geofenceListViewModel: viewModel,
                        viewContext: viewContext
                    )
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: locationManager.monitoringStatus) { oldValue, newValue in
                print("🔄 DEBUG: GeofenceListView - Monitoring status changed")
                print("  - Old value: \(oldValue)")
                print("  - New value: \(newValue)")
                print("  - Is showing add sheet: \(showingAddGeofence)")
                
                Task {
                    await viewModel.fetchGeofences()
                    await stateController.processStateUpdate()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startObserving()
            Task {
                await viewModel.fetchGeofences()
            }
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }
}

private struct GeofenceListContent: View {
    @ObservedObject var viewModel: GeofenceListViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showAddSheet = false
    
    private var sortedGeofences: [Geofence] {
        guard let userLocation = locationManager.userLocation else {
            return viewModel.geofences
        }
        
        return viewModel.geofences.sorted { geofence1, geofence2 in
            let location1 = CLLocation(latitude: geofence1.latitude, longitude: geofence1.longitude)
            let location2 = CLLocation(latitude: geofence2.latitude, longitude: geofence2.longitude)
            
            let distance1 = location1.distance(from: userLocation)
            let distance2 = location2.distance(from: userLocation)
            
            let unit = DistanceUnit(rawValue: UserDefaults.standard.string(forKey: "distanceUnit") ?? "") ?? .kilometers
            print("📏 DEBUG: Distance comparison - \(geofence1.name ?? "Unknown"): \(distance1.formatted(unit: unit)) vs \(geofence2.name ?? "Unknown"): \(distance2.formatted(unit: unit))")
            
            return distance1 < distance2
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Status Section
                StatusSection(viewModel: viewModel)
                    .padding(.horizontal)
                
                // Main Content
                if sortedGeofences.isEmpty {
                    ListEmptyStateView(showAddSheet: $showAddSheet)
                } else {
                    GeofenceListItems(viewModel: viewModel, geofences: sortedGeofences)
                }
            }
            .padding(.top, 8)
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.purple)
                            .background(Circle().fill(Color(.secondarySystemGroupedBackground)).shadow(radius: 4))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add new Silent Circle")
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddGeofenceView(
                    geofenceListViewModel: viewModel,
                    viewContext: viewContext
                )
            }
        }
    }
}

private struct StatusSection: View {
    @ObservedObject var viewModel: GeofenceListViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.colorScheme) var colorScheme
    
    private var activeGeofencesCount: Int {
        viewModel.geofences.filter { $0.isActive }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Current Status Card
            CurrentStatusCard(locationManager: locationManager)
            
            // Quick Stats Row
            HStack(spacing: 16) {
                StatCard(
                    title: "Active Circles",
                    value: "\(activeGeofencesCount)",
                    icon: "bell.circle.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "Total Circles",
                    value: "\(viewModel.geofences.count)",
                    icon: "circle.grid.2x2.fill",
                    color: .purple
                )
            }
        }
        .onChange(of: viewModel.geofences) { oldValue, newValue in
            Task {
                await viewModel.fetchGeofences()
            }
        }
        .onChange(of: locationManager.monitoringStatus) { oldValue, newValue in
            Task {
                await viewModel.fetchGeofences()
            }
        }
    }
}

private struct CurrentStatusCard: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Location Status
            HStack(spacing: 16) {
                StatusIndicatorView(
                    status: locationManager.monitoringStatus,
                    isLocation: true
                )
                
                if let currentGeofence = locationManager.currentGeofence {
                    Divider()
                        .frame(height: 24)
                    
                    // Active Circle Status
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.purple)
                            .frame(width: 8, height: 8)
                        
                        Text(currentGeofence.name ?? "Unknown")
                            .font(.subheadline.weight(.medium))
                        
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.purple.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .onAppear {
            logCurrentGeofence()
        }
    }
    
    private func logCurrentGeofence() {
        if let currentGeofence = locationManager.currentGeofence {
            print("🔄 DEBUG: Current active geofence: \(currentGeofence.name ?? "Unknown")")
        } else {
            print("ℹ️ DEBUG: No active geofence")
        }
    }
}

private struct StatusIndicatorView: View {
    let status: LocationManager.MonitoringStatus
    let isLocation: Bool
    
    var statusConfig: (icon: String, color: Color, text: String) {
        if isLocation {
            switch status {
            case .ready:
                return ("location.fill", .purple, "Location Available")
            case .noLocation:
                return ("location.slash.fill", .orange, "Location Disabled")
            case .notAuthorized:
                return ("exclamationmark.triangle.fill", .red, "Permission Required")
            case .noGeofences:
                return ("location.fill", .purple, "Ready to Monitor")
            case .unknown:
                return ("location.circle", .gray, "Checking Status...")
            }
        } else {
            switch status {
            case .ready:
                return ("checkmark.circle.fill", .purple, "Monitoring Active")
            case .noLocation:
                return ("xmark.circle.fill", .orange, "Location Required")
            case .notAuthorized:
                return ("exclamationmark.triangle.fill", .red, "Permission Required")
            case .noGeofences:
                return ("circle.dotted", .purple, "No Active Circles")
            case .unknown:
                return ("circle", .gray, "Checking Status...")
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusConfig.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusConfig.color)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(statusConfig.color.opacity(0.1))
                        .frame(width: 28, height: 28)
                )
            
            Text(statusConfig.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isLocation ? "Location" : "Monitoring") Status: \(statusConfig.text)")
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct ListEmptyStateView: View {
    @Binding var showAddSheet: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
            
            Text("No Silent Circles Yet")
                .font(.title2.bold())
            
            Text("Add your first Silent Circle to automatically silence your device in specific locations.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            
            Button(action: { showAddSheet = true }) {
                Label("Add Circle", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct GeofenceListItems: View {
    @ObservedObject var viewModel: GeofenceListViewModel
    let geofences: [Geofence]
    
    var body: some View {
        GeofenceList(viewModel: viewModel, geofences: geofences)
            .background(Color(.systemGroupedBackground))
    }
}

private struct GeofenceList: View {
    @ObservedObject var viewModel: GeofenceListViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var locationManager: LocationManager
    let geofences: [Geofence]
    @State private var selectedGeofence: Geofence?
    @State private var showingDeleteAlert = false
    @State private var geofenceToDelete: Geofence?
    private let id = UUID()
    
    private var sortedGeofences: [Geofence] {
        guard let userLocation = locationManager.userLocation else {
            print("📍 DEBUG: No user location available, showing unsorted list")
            return geofences
        }
        
        return geofences.sorted { geofence1, geofence2 in
            let location1 = CLLocation(latitude: geofence1.latitude, longitude: geofence1.longitude)
            let location2 = CLLocation(latitude: geofence2.latitude, longitude: geofence2.longitude)
            
            let distance1 = location1.distance(from: userLocation)
            let distance2 = location2.distance(from: userLocation)
            
            let unit = DistanceUnit(rawValue: UserDefaults.standard.string(forKey: "distanceUnit") ?? "") ?? .kilometers
            print("📏 DEBUG: Distance comparison - \(geofence1.name ?? "Unknown"): \(distance1.formatted(unit: unit)) vs \(geofence2.name ?? "Unknown"): \(distance2.formatted(unit: unit))")
            
            return distance1 < distance2
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedGeofences) { geofence in
                    ZStack {
                        GeofenceCell(
                            geofence: geofence,
                            isActive: locationManager.currentGeofence?.id == geofence.id,
                            onTap: { geofence in
                                print("👆 DEBUG: Tapped geofence: \(geofence.name ?? "Unnamed")")
                                selectedGeofence = geofence
                            }
                        )
                        // Make the entire cell tappable with proper hit target (44x44 minimum)
                        .contentShape(Rectangle())
                        .frame(minHeight: 44)
                    }
                    .contextMenu {
                        // Edit Button
                        Button {
                            selectedGeofence = geofence
                        } label: {
                            Label("Edit Circle", systemImage: "pencil")
                        }
                        
                        // Delete Button
                        Button(role: .destructive) {
                            print("🗑️ DEBUG: Delete menu triggered for geofence: \(geofence.name ?? "Unnamed")")
                            geofenceToDelete = geofence
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Circle", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            print("🗑️ DEBUG: Swipe action triggered for geofence: \(geofence.name ?? "Unnamed")")
                            geofenceToDelete = geofence
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(item: $selectedGeofence) { geofence in
            UpdateGeofenceView(
                geofenceListViewModel: viewModel,
                viewContext: viewContext,
                geofence: geofence
            )
        }
        .alert("Delete Silent Circle?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                geofenceToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let geofence = geofenceToDelete {
                    print("🗑️ DEBUG: Confirming deletion for geofence: \(geofence.name ?? "Unnamed")")
                    viewModel.deleteGeofence(geofence, locationManager: locationManager)
                }
                geofenceToDelete = nil
            }
        } message: {
            if let name = geofenceToDelete?.name {
                Text("Are you sure you want to delete \"\(name)\"? This action cannot be undone.")
            } else {
                Text("Are you sure you want to delete this Silent Circle? This action cannot be undone.")
            }
        }
    }
}

#Preview {
    let viewContext = PersistenceController.preview.container.viewContext
    let geofenceListViewModel = GeofenceListViewModel(viewContext: viewContext)
    let locationManager = LocationManager()
    
    NavigationView {
        GeofenceListView(viewModel: geofenceListViewModel)
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(locationManager)
    }
}
