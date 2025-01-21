import SwiftUI
import MessageUI

enum DistanceUnit: String, CaseIterable {
    case kilometers
    case miles
}

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            print("🔄 DEBUG: Location Circle enabled: \(isEnabled)")
        }
    }
    
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
            print("🔄 DEBUG: Distance unit changed to: \(distanceUnit)")
        }
    }
    
    @Published var isTestingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isTestingEnabled, forKey: "isTestingEnabled")
            print("🧪 DEBUG: Testing mode enabled: \(isTestingEnabled)")
        }
    }
    
    // MARK: - Properties
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // MARK: - Initialization
    init() {
        // Load saved settings with default values
        self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled", defaultValue: true)
        self.distanceUnit = DistanceUnit(rawValue: UserDefaults.standard.string(forKey: "distanceUnit") ?? "") ?? .kilometers
        #if DEBUG
        self.isTestingEnabled = UserDefaults.standard.bool(forKey: "isTestingEnabled", defaultValue: true)
        #else
        self.isTestingEnabled = false
        #endif
        
        print("📱 DEBUG: SettingsViewModel initialized")
        print("  - Enabled: \(isEnabled)")
        print("  - Distance Unit: \(distanceUnit)")
        print("  - Testing Enabled: \(isTestingEnabled)")
    }
    
    // MARK: - Methods
    func openLocationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            print("🔄 DEBUG: Opening location settings")
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            print("🔄 DEBUG: Opening notification settings")
        }
    }
    
    func contactSupport() {
        let email = "support@silentcircle.app"
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
            print("📧 DEBUG: Opening mail composer for support")
        }
    }
}

extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            set(defaultValue, forKey: key)
            return defaultValue
        }
        return bool(forKey: key)
    }
} 