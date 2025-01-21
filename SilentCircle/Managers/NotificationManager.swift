import UserNotifications
import AVFoundation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static var shared = NotificationManager()
    private var hasShownInitialNotification = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkNotificationAuthorization()
    }
    
    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.requestAuthorization()
            } else if settings.authorizationStatus != .authorized {
                print("⚠️ DEBUG: Notifications not authorized. Current status: \(settings.authorizationStatus)")
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ DEBUG: Notification authorization granted")
                if !self.hasShownInitialNotification {
                    DispatchQueue.main.async {
                        self.hasShownInitialNotification = true
                        self.scheduleNotification(
                            title: "Location Circle Active",
                            body: "You'll receive reminders to silence your phone in your saved locations"
                        )
                    }
                }
            } else {
                print("❌ DEBUG: Notification authorization denied")
                if let error = error {
                    print("❌ DEBUG: Authorization error: \(error.localizedDescription)")
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
    
    // Add method to handle geofence entry
    func handleGeofenceEntry(geofenceName: String) {
        print("📍 DEBUG: Handling geofence entry for: \(geofenceName)")
        sendNotification(
            title: "Entering \(geofenceName)",
            body: "You've entered \(geofenceName). Remember to silence your phone!"
        )
    }
    
    func handleGeofenceExit(geofenceName: String) {
        print("📍 DEBUG: Handling geofence exit for: \(geofenceName)")
        sendNotification(
            title: "Exiting \(geofenceName)",
            body: "You've left \(geofenceName). You can unmute your phone now."
        )
    }
    
    private func sendNotification(title: String, body: String) {
        print("📱 DEBUG: Sending notification - Title: \(title)")
        scheduleNotification(title: title, body: body) { success in
            if success {
                print("✅ DEBUG: Notification scheduled successfully")
            } else {
                print("❌ DEBUG: Failed to schedule notification")
            }
        }
    }
} 