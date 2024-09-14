import Foundation

class Habit: Scheduleable, Codable {
    var id: UUID
    var title: String
    var description: String?
    var isScheduled: Bool = true // Habits are always scheduled
    var scheduledDate: Date?
    var scheduledTime: Date?
    var duration: TimeInterval?
    var priority: Int = 2 // Default priority: medium
    var dueDate: Date? // Not applicable for habits
    var reminder: Date?
    var tags: [String]?
    var project: String?
    var frequency: HabitFrequency
    var streak: Int = 0
    var streakFreezeAvailable: Bool = true // One freeze per day by default
    var goal: Double?
    var goalProgress: Double = 0.0
    var notes: String?
    var specificDays: [Int]? // Days of the week (1 for Sunday, 2 for Monday, ..., 7 for Saturday)
    var cloudKitRecordID: CKRecord.ID?

    enum HabitFrequency: String, CaseIterable, Codable {
        case daily = "Daily"
        case weekly = "Weekly"
        case specificDays = "Specific Days"
        // Add more frequencies as needed
    }

    init(id: UUID = UUID(), title: String, description: String? = nil, isScheduled: Bool = true, scheduledDate: Date? = nil, scheduledTime: Date? = nil, duration: TimeInterval? = nil, priority: Int = 2, dueDate: Date? = nil, reminder: Date? = nil, tags: [String]? = nil, project: String? = nil, frequency: HabitFrequency = .daily) {
        self.id = id
        self.title = title
        self.description = description
        self.isScheduled = isScheduled
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.duration = duration
        self.priority = priority
        self.reminder = reminder
        self.tags = tags
        self.project = project
        self.frequency = frequency
    }

    func schedule(date: Date, time: Date) throws {
        try super.schedule(date: date, time: time)
    }

    func reschedule(date: Date, time: Date) throws {
        try super.reschedule(date: date, time: time)
    }

    func markAsComplete(on date: Date) {
        if let lastCompletionDate = scheduledDate, !Calendar.current.isDate(date, inSameDayAs: lastCompletionDate) {
            if !streakFreezeAvailable {
                streak = 0
            } else {
                streakFreezeAvailable = false
            }
        }

        streak += 1
        scheduledDate = date

        if let goal = goal {
            goalProgress += 1
        }

        scheduleNextOccurrence(from: date)
    }

    private func scheduleNextOccurrence(from date: Date) {
        switch frequency {
        case .daily:
            if let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date) {
                try? schedule(date: nextDate, time: scheduledTime ?? Date())
            }
        case .weekly:
            if let nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: date) {
                try? schedule(date: nextDate, time: scheduledTime ?? Date())
            }
        case .specificDays:
            let calendar = Calendar.current
            let todayWeekday = calendar.component(.weekday, from: date)

            guard let specificDays = specificDays, !specificDays.isEmpty else { return }

            var nextWeekday = specificDays.first(where: { $0 > todayWeekday })
            if nextWeekday == nil {
                nextWeekday = specificDays.first
            }

            let daysToAdd = (nextWeekday! - todayWeekday + 7) % 7

            if let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: date) {
                try? schedule(date: nextDate, time: scheduledTime ?? Date())
            }
        }
    }

    func useStreakFreeze() {
        if streakFreezeAvailable {
            streakFreezeAvailable = false
        }
    }

    func updateGoalProgress(progress: Double) {
        self.goalProgress = progress
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, description, isScheduled, scheduledDate, scheduledTime, duration, priority, dueDate, reminder, tags, project, frequency, streak, streakFreezeAvailable, goal, goalProgress, notes, specificDays, cloudKitRecordID
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
        try container.encode(frequency.rawValue, forKey: .frequency)
        try container.encode(streak, forKey: .streak)
        try container.encode(streakFreezeAvailable, forKey: .streakFreezeAvailable)
        try container.encode(goal, forKey: .goal)
        try container.encode(goalProgress, forKey: .goalProgress)
        try container.encode(notes, forKey: .notes)
        try container.encode(specificDays, forKey: .specificDays)
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
        let frequencyRawValue = try container.decode(String.self, forKey: .frequency)
        frequency = HabitFrequency(rawValue: frequencyRawValue) ?? .daily
        streak = try container.decode(Int.self, forKey: .streak)
        streakFreezeAvailable = try container.decode(Bool.self, forKey: .streakFreezeAvailable)
        goal = try container.decodeIfPresent(Double.self, forKey: .goal)
        goalProgress = try container.decode(Double.self, forKey: .goalProgress)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        specificDays = try container.decodeIfPresent([Int].self, forKey: .specificDays)
        cloudKitRecordID = try container.decodeIfPresent(CKRecord.ID.self, forKey: .cloudKitRecordID)
    }
}
