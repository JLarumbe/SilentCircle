import UserNotifications

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
} 