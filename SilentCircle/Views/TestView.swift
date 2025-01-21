import SwiftUI
import CoreData

struct TestView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var testManager = TestManager.shared
    @State private var selectedGeofence: Geofence?
    
    var body: some View {
        List {
            Section("Test Controls") {
                Toggle("Test Mode", isOn: $testManager.isTestMode)
                    .onChange(of: testManager.isTestMode) { oldValue, newValue in
                        if newValue {
                            testManager.startTestMode()
                        } else {
                            testManager.stopTestMode()
                            // Clear test logs when disabling test mode
                            testManager.testLogs.removeAll()
                        }
                    }
                
                if testManager.isTestMode {
                    Button("Create Test Geofence") {
                        testManager.testGeofenceCreation(viewContext: viewContext)
                    }
                    
                    Button("Test Notification") {
                        testManager.testNotificationDelivery()
                    }
                    
                    // Geofence Picker
                    if let geofences = try? viewContext.fetch(Geofence.fetchRequest()) {
                        Picker("Select Geofence", selection: $selectedGeofence) {
                            Text("None").tag(Optional<Geofence>.none)
                            ForEach(geofences) { geofence in
                                Text(geofence.name ?? "Unknown").tag(Optional(geofence))
                            }
                        }
                        
                        if let geofence = selectedGeofence {
                            Button("Simulate Entry") {
                                Task {
                                    await testManager.simulateGeofenceEntry(locationManager: locationManager, geofence: geofence)
                                }
                            }
                            
                            Button("Simulate Exit") {
                                Task {
                                    await testManager.simulateGeofenceExit(locationManager: locationManager, geofence: geofence)
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Test Logs") {
                ForEach(testManager.testLogs.reversed()) { log in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(log.success ? "✅" : "❌")
                            Text(log.message)
                                .font(.subheadline)
                        }
                        Text(log.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Testing")
    }
} 