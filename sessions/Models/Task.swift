import Foundation

class Task: Scheduleable, Codable {
    var id: UUID
    var title: String
    var description: String?
    var isScheduled: Bool = false
    var scheduledDate: Date?
    var scheduledTime: Date?
    var duration: TimeInterval?
    var priority: Int = 2 // Default priority: medium
    var dueDate: Date?
    var reminder: Date?
    var tags: [String]?
    var project: String?
    var status: TaskStatus = .notStarted
    var subtasks: [Task]?
    var cloudKitRecordID: CKRecord.ID?

    enum TaskStatus: String, CaseIterable, Codable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case done = "Done"
    }

    init(id: UUID = UUID(), title: String, description: String? = nil, isScheduled: Bool = false, scheduledDate: Date? = nil, scheduledTime: Date? = nil, duration: TimeInterval? = nil, priority: Int = 2, dueDate: Date? = nil, reminder: Date? = nil, tags: [String]? = nil, project: String? = nil, status: TaskStatus = .notStarted) {
        self.id = id
        self.title = title
        self.description = description
        self.isScheduled = isScheduled
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.duration = duration
        self.priority = priority
        self.dueDate = dueDate
        self.reminder = reminder
        self.tags = tags
        self.project = project
        self.status = status
    }

    // No need to implement schedule and reschedule as they have default implementations in the Scheduleable extension

    func markAsComplete() {
        status = .done

        if let subtasks = subtasks {
            for subtask in subtasks {
                subtask.markAsComplete()
            }
        }

        if let fixedRoutine = findFixedRoutineContainingTask(self) {
            fixedRoutine.taskCompleted(task: self)
        }
    }

    func startTask() {
        status = .inProgress
    }

    func pauseTask() {
        // No specific action for pausing a task, but could be used for tracking purposes in the future
    }

    func addSubtask(task: Task) {
        if subtasks == nil {
            subtasks = []
        }
        subtasks?.append(task)
    }

    func removeSubtask(task: Task) {
        subtasks?.removeAll(where: { $0.id == task.id })
    }

    private func findFixedRoutineContainingTask(_ task: Task) -> FixedRoutine? {
        let routineManager = RoutineManager.shared
        return routineManager.fixedRoutines.first { routine in
            routine.tasks.contains { $0.id == task.id }
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, description, isScheduled, scheduledDate, scheduledTime, duration, priority, dueDate, reminder, tags, project, status, subtasks, cloudKitRecordID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(isScheduled, forKey: .isScheduled)
        try container.encode(scheduledDate, forKey: .scheduledDate)
        try container.encode(scheduledTime, forKey: .scheduledTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(priority, forKey: .priority)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(reminder, forKey: .reminder)
        try container.encode(tags, forKey: .tags)
        try container.encode(project, forKey: .project)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(subtasks, forKey: .subtasks)
        try container.encode(cloudKitRecordID, forKey: .cloudKitRecordID)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isScheduled = try container.decode(Bool.self, forKey: .isScheduled)
        scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
        scheduledTime = try container.decodeIfPresent(Date.self, forKey: .scheduledTime)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        priority = try container.decode(Int.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        reminder = try container.decodeIfPresent(Date.self, forKey: .reminder)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        let statusRawValue = try container.decode(String.self, forKey: .status)
        status = TaskStatus(rawValue: statusRawValue) ?? .notStarted
        subtasks = try container.decodeIfPresent([Task].self, forKey: .subtasks)
        cloudKitRecordID = try container.decodeIfPresent(CKRecord.ID.self, forKey: .cloudKitRecordID)
    }
}
