import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init() {
        // Create the view model directly since we're in a synchronous context
        let viewModel = SettingsViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // General Settings Section
                Section("General") {
                    Toggle("Enable Silent Circle", isOn: $viewModel.isEnabled)
                        .tint(.purple)
                    
                    Picker("Sound Mode", selection: $viewModel.soundMode) {
                        Text("Silent").tag(SoundMode.silent)
                        Text("Vibrate").tag(SoundMode.vibrate)
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle("Notify on Entry/Exit", isOn: $viewModel.notificationsEnabled)
                        .tint(.purple)
                }
                
                // Distance Unit Section
                Section("Distance Unit") {
                    Picker("Unit", selection: $viewModel.distanceUnit) {
                        Text("Kilometers").tag(DistanceUnit.kilometers)
                        Text("Miles").tag(DistanceUnit.miles)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Privacy & Permissions Section
                Section("Privacy & Permissions") {
                    Button(action: viewModel.openLocationSettings) {
                        HStack {
                            Text("Location Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(action: viewModel.openNotificationSettings) {
                        HStack {
                            Text("Notification Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: viewModel.contactSupport) {
                        HStack {
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "envelope")
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
    }
}

#Preview {
    SettingsView()
} 