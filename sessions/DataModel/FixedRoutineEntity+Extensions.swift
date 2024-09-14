import Foundation

extension FixedRoutineEntity {
    func toFixedRoutine() -> FixedRoutine {
        let tasks = (self.tasks?.allObjects as? [TaskEntity])?.map { $0.toTask() } ?? []
        let recurrence = FixedRoutine.Recurrence(rawValue: self.recurrence ?? "") ?? .daily
        return FixedRoutine(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            description: self.routineDescription,
            tasks: tasks,
            recurrence: recurrence,
            startTime: self.startTime,
            flexibility: self.flexibility?.doubleValue,
            specificDays: self.specificDays?.components(separatedBy: ",").compactMap { Int($0) } // Safely unwrap specificDays
        )
    }
}
