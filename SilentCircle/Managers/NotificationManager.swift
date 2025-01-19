import UserNotifications
import AVFoundation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static var shared = NotificationManager()
    private var hasShownInitialNotification = false
    
    // Store the previous ringer state to restore it when exiting geofence
    private var previousRingerState: Bool?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkNotificationAuthorization()
    }
    
    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.requestAuthorization()
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted && !self.hasShownInitialNotification {
                // Only show welcome notification the first time permissions are granted
                DispatchQueue.main.async {
                    self.hasShownInitialNotification = true
                    self.scheduleNotification(
                        title: "Notifications Enabled",
                        body: "You will now receive Silent Circle notifications"
                    )
                }
            }
        }
    }
    
    // Add delegate methods to track notification lifecycle
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("📱 Will present notification: \(notification.request.identifier)")
        return [.banner, .sound, .badge]  // Explicitly request presentation options
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("👆 User interacted with notification: \(response.notification.request.identifier)")
        completionHandler()  // Important: Call the completion handler when done
    }
    
    func scheduleNotification(title: String, body: String, completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Authorization error: \(error.localizedDescription)")
                completion?(false)
                return
            }
            
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = UNNotificationSound.defaultCritical
                
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Notification error: \(error.localizedDescription)")
                        completion?(false)
                    } else {
                        completion?(true)
                    }
                }
            } else {
                print("⚠️ Notification permission denied")
                completion?(false)
            }
        }
    }
    
    // Add method to handle sound mode changes
    func handleGeofenceEntry() {
        print("🔇 DEBUG: Handling geofence entry")
        let soundMode = SoundMode(rawValue: UserDefaults.standard.string(forKey: "soundMode") ?? "") ?? .silent
        
        // Store current ringer state before changing it
        previousRingerState = try? AVAudioSession.sharedInstance().isOtherAudioPlaying
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, options: [])
            try audioSession.setActive(true)
            
            switch soundMode {
            case .silent:
                print("🔕 DEBUG: Setting phone to silent mode")
                try audioSession.setMode(.default)
            case .vibrate:
                print("📳 DEBUG: Setting phone to vibrate mode")
                try audioSession.setMode(.videoChat) // This enables vibration
            }
        } catch {
            print("❌ DEBUG: Failed to change sound mode: \(error.localizedDescription)")
        }
    }
    
    func handleGeofenceExit() {
        print("🔊 DEBUG: Handling geofence exit")
        
        // Restore previous ringer state
        if let wasRinging = previousRingerState {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false)
                if wasRinging {
                    print("🔔 DEBUG: Restoring previous ringer state")
                    try audioSession.setMode(.default)
                }
            } catch {
                print("❌ DEBUG: Failed to restore sound mode: \(error.localizedDescription)")
            }
        }
        previousRingerState = nil
    }
} 