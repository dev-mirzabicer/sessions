import Foundation

extension TaskEntity {
    func toTask() -> Task {
        return Task(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            description: self.taskDescription,
            isScheduled: self.isScheduled,
            scheduledDate: self.scheduledDate,
            scheduledTime: self.scheduledTime,
            duration: self.duration?.doubleValue, // Safely unwrap duration
            priority: Int(self.priority),
            dueDate: self.dueDate,
            reminder: self.reminder,
            tags: self.tags?.components(separatedBy: ","),
            project: self.project,
            status: Task.TaskStatus(rawValue: self.status ?? "") ?? .notStarted
        )
    }
}
