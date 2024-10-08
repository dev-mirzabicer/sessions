import Foundation
import UserNotifications

protocol Scheduleable: AnyObject, Identifiable {

    var title: String { get set }
    var description: String? { get set }
    var isScheduled: Bool { get set }
    var scheduledDate: Date? { get set }
    var scheduledTime: Date? { get set }
    var duration: TimeInterval? { get set }
    var priority: Int { get set } // 1-low, 2-medium, 3-high
    var dueDate: Date? { get set }
    var reminder: Date? { get set }
    var tags: [String]? { get set }
    var project: String? { get set }
    var cloudKitRecordID: CKRecord.ID? { get set }

    func schedule(date: Date, time: Date) throws
    func reschedule(date: Date, time: Date) throws
    func markAsComplete()
}

// Separate protocol for notification scheduling
protocol NotificationScheduleable: Scheduleable {
    func scheduleNotification(with title: String, body: String, at date: Date)
}

// Default implementations for Scheduleable methods
extension Scheduleable {
    func schedule(date: Date, time: Date) {
        self.scheduledDate = date
        self.scheduledTime = time
        self.isScheduled = true
    }

    func reschedule(date: Date, time: Date) {
        self.scheduledDate = date
        self.scheduledTime = time
    }

    func markAsComplete() {
        // Default implementation can be empty or provide common functionality
    }
}

// Default implementation for NotificationScheduleable method
extension NotificationScheduleable {
    func scheduleNotification(with title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
