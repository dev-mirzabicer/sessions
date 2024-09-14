import Foundation

extension HabitEntity {
    func toHabit() -> Habit {
        return Habit(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            description: self.habitDescription,
            isScheduled: self.isScheduled,
            scheduledDate: self.scheduledDate,
            scheduledTime: self.scheduledTime,
            duration: self.duration,
            priority: Int(self.priority),
            reminder: self.reminder,
            tags: self.tags?.components(separatedBy: ","),
            project: self.project,
            frequency: Habit.HabitFrequency(rawValue: self.frequency ?? "") ?? .daily,
            streak: Int(self.streak),
            streakFreezeAvailable: self.streakFreezeAvailable,
            goal: self.goal,
            goalProgress: self.goalProgress,
            notes: self.notes,
            specificDays: self.specificDays?.components(separatedBy: ",").compactMap { Int($0) }
        )
    }
}
