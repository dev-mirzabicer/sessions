import UIKit

class BackgroundTaskService {
    static let shared = BackgroundTaskService() // Singleton instance

    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    private init() {} // Private initializer to enforce singleton pattern

    func startBackgroundTask(withName taskName: String, expirationHandler: @escaping () -> Void) {
        // End any existing background task
        endBackgroundTask()

        // Start a new background task
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName, expirationHandler: expirationHandler)
    }

    func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
}
