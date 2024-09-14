import Foundation
import UIKit
import Combine

class FixedRoutine: Codable {
    var id: UUID
    var title: String
    var description: String?
    var tasks: [Task]
    var duration: TimeInterval {
        return tasks.reduce(0) { $0 + ($1.duration ?? 0) }
    }
    var recurrence: Recurrence
    var startTime: Date?
    var flexibility: TimeInterval?
    var cloudKitRecordID: CKRecord.ID?

    private var currentTaskIndex: Int = 0
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var elapsedTime: TimeInterval = 0
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    enum Recurrence: String, CaseIterable, Codable {
        case daily = "Daily"
        case weekly = "Weekly"
        case specificDays = "Specific Days"
    }

    init(id: UUID = UUID(), title: String, description: String? = nil, tasks: [Task], recurrence: Recurrence, startTime: Date? = nil, flexibility: TimeInterval? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.tasks = tasks
        self.recurrence = recurrence
        self.startTime = startTime
        self.flexibility = flexibility
    }

    func startRoutine() {
        guard currentTaskIndex < tasks.count else { return }

        let currentTask = tasks[currentTaskIndex]
        currentTask.startTask()

        // Start background task using BackgroundTaskService
        BackgroundTaskService.shared.startBackgroundTask(withName: "FixedRoutineTimer") {
            self.pauseRoutine()
            self.saveRoutineProgress()
        }

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pauseRoutine() {
        timer?.cancel()
        timer = nil

        // End background task using BackgroundTaskService
        BackgroundTaskService.shared.endBackgroundTask()
    }

    func nextTask() {
        pauseRoutine()
        currentTaskIndex += 1

        if currentTaskIndex < tasks.count {
            startRoutine()
        } else {
            completeRoutine()
        }
    }

    func completeRoutine() {
        pauseRoutine()
        currentTaskIndex = 0
        elapsedTime = 0

        for task in tasks {
            task.markAsComplete()
        }
    }

    func resetRoutine() {
        pauseRoutine()
        currentTaskIndex = 0
        elapsedTime = 0

        for task in tasks {
            task.status = .notStarted
        }
    }

    func getCurrentTask() -> Task? {
        guard currentTaskIndex < tasks.count else { return nil }
        return tasks[currentTaskIndex]
    }

    func getProgress() -> Double {
        let totalDuration = duration
        guard totalDuration > 0 else { return 0 }

        let completedDuration = tasks[0..<currentTaskIndex].reduce(0) { $0 + ($1.duration ?? 0) } + elapsedTime
        return completedDuration / totalDuration
    }

    // MARK: - Routine Progress Saving/Loading

    private func saveRoutineProgress() {
        let progressData = ["currentTaskIndex": currentTaskIndex, "elapsedTime": elapsedTime]
        UserDefaults.standard.set(progressData, forKey: "fixedRoutineProgress_\(id)")
    }

    func loadRoutineProgress() {
        if let progressData = UserDefaults.standard.dictionary(forKey: "fixedRoutineProgress_\(id)") as? [String: Any] {
            currentTaskIndex = progressData["currentTaskIndex"] as? Int ?? 0
            elapsedTime = progressData["elapsedTime"] as? TimeInterval ?? 0
        }
    }

    func shouldOccur(on date: Date) -> Bool {
        guard let startTime = startTime else { return false }

        let calendar = Calendar.current

        switch recurrence {
        case .daily:
            return calendar.isDate(date, inSameDayAs: startTime)
        case .weekly:
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: startTime)
        case .specificDays:
            let weekday = calendar.component(.weekday, from: date)
            return specificDays?.contains(weekday) ?? false
        }
    }

    func taskCompleted(task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }), index == currentTaskIndex {
            nextTask()
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, description, tasks, recurrence, startTime, flexibility, cloudKitRecordID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(recurrence.rawValue, forKey: .recurrence)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(flexibility, forKey: .flexibility)
        try container.encode(cloudKitRecordID, forKey: .cloudKitRecordID)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        tasks = try container.decode([Task].self, forKey: .tasks)
        let recurrenceRawValue = try container.decode(String.self, forKey: .recurrence)
        recurrence = Recurrence(rawValue: recurrenceRawValue) ?? .daily
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        flexibility = try container.decodeIfPresent(TimeInterval.self, forKey: .flexibility)
        cloudKitRecordID = try container.decodeIfPresent(CKRecord.ID.self, forKey: .cloudKitRecordID)
    }
}
