import Foundation
@testable import SilentCircle

class MockNotificationManager: NotificationManager {
    var notifications: [(title: String, body: String)] = []
    
    override init() {
        super.init()
    }
    
    override func scheduleNotification(title: String, body: String) {
        notifications.append((title: title, body: body))
    }
} 