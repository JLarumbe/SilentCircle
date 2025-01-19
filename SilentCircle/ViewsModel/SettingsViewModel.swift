import SwiftUI
import MessageUI

enum SoundMode: String, CaseIterable {
    case silent
    case vibrate
}

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
            print("🔄 DEBUG: Silent Circle enabled: \(isEnabled)")
        }
    }
    
    @Published var soundMode: SoundMode {
        didSet {
            UserDefaults.standard.set(soundMode.rawValue, forKey: "soundMode")
            print("🔄 DEBUG: Sound mode changed to: \(soundMode)")
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            print("🔔 DEBUG: Notifications setting changed: \(notificationsEnabled)")
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            print("🔔 DEBUG: Saved to UserDefaults: \(UserDefaults.standard.bool(forKey: "notificationsEnabled", defaultValue: false))")
        }
    }
    
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
            print("🔄 DEBUG: Distance unit changed to: \(distanceUnit)")
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
        self.soundMode = SoundMode(rawValue: UserDefaults.standard.string(forKey: "soundMode") ?? "") ?? .silent
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        self.distanceUnit = DistanceUnit(rawValue: UserDefaults.standard.string(forKey: "distanceUnit") ?? "") ?? .kilometers
        
        print("📱 DEBUG: SettingsViewModel initialized")
        print("  - Enabled: \(isEnabled)")
        print("  - Sound Mode: \(soundMode)")
        print("  - Notifications: \(notificationsEnabled)")
        print("  - Distance Unit: \(distanceUnit)")
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