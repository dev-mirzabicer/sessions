import CoreData
import CloudKit

class DataManager: ObservableObject {
    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SessionsModel")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // MARK: - Error Handling

    @Published var error: Error?

    // MARK: - Data Operations

    // Tasks
    func fetchTasks() throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        return try viewContext.fetch(fetchRequest)
    }

    func saveTask(title: String, description: String?, isScheduled: Bool, scheduledDate: Date?, scheduledTime: Date?, duration: TimeInterval?, priority: Int, dueDate: Date?, reminder: Date?, tags: [String]?, project: String?, status: Task.TaskStatus) throws {
        let task = TaskEntity(context: viewContext)
        task.id = UUID()
        task.title = title
        task.taskDescription = description
        task.isScheduled = isScheduled
        task.scheduledDate = scheduledDate
        task.scheduledTime = scheduledTime
        task.duration = duration as NSNumber?
        task.priority = Int16(priority)
        task.dueDate = dueDate
        task.reminder = reminder
        task.tags = tags?.joined(separator: ",")
        task.project = project
        task.status = status.rawValue

        try saveContext()
    }

    func updateTask(_ task: TaskEntity, title: String, description: String?, isScheduled: Bool, scheduledDate: Date?, scheduledTime: Date?, duration: TimeInterval?, priority: Int, dueDate: Date?, reminder: Date?, tags: [String]?, project: String?, status: Task.TaskStatus) throws {
        task.title = title
        task.taskDescription = description
        task.isScheduled = isScheduled
        task.scheduledDate = scheduledDate
        task.scheduledTime = scheduledTime
        task.duration = duration as NSNumber?
        task.priority = Int16(priority)
        task.dueDate = dueDate
        task.reminder = reminder
        task.tags = tags?.joined(separator: ",")
        task.project = project
        task.status = status.rawValue

        try saveContext()
    }

    func deleteTask(_ task: TaskEntity) throws {
        viewContext.delete(task)
        try saveContext()
    }

    // Habits
    func fetchHabits() throws -> [HabitEntity] {
        let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        return try viewContext.fetch(fetchRequest)
    }

    func saveHabit(title: String, description: String?, isScheduled: Bool, scheduledDate: Date?, scheduledTime: Date?, duration: TimeInterval?, priority: Int, dueDate: Date?, reminder: Date?, tags: [String]?, project: String?, frequency: Habit.HabitFrequency, streak: Int, streakFreezeAvailable: Bool, goal: Double?, goalProgress: Double, notes: String?, specificDays: [Int]?) throws {
        let habit = HabitEntity(context: viewContext)
        habit.id = UUID()
        habit.title = title
        habit.habitDescription = description
        habit.isScheduled = isScheduled
        habit.scheduledDate = scheduledDate
        habit.scheduledTime = scheduledTime
        habit.duration = duration as NSNumber?
        habit.priority = Int16(priority)
        habit.dueDate = dueDate
        habit.reminder = reminder
        habit.tags = tags?.joined(separator: ",")
        habit.project = project
        habit.frequency = frequency.rawValue
        habit.streak = Int16(streak)
        habit.streakFreezeAvailable = streakFreezeAvailable
        habit.goal = goal as NSNumber?
        habit.goalProgress = goalProgress
        habit.notes = notes
        habit.specificDays = specificDays?.map { String($0) }?.joined(separator: ",")

        try saveContext()
    }

    func updateHabit(_ habit: HabitEntity, title: String, description: String?, isScheduled: Bool, scheduledDate: Date?, scheduledTime: Date?, duration: TimeInterval?, priority: Int, dueDate: Date?, reminder: Date?, tags: [String]?, project: String?, frequency: Habit.HabitFrequency, streak: Int, streakFreezeAvailable: Bool, goal: Double?, goalProgress: Double, notes: String?, specificDays: [Int]?) throws {
        habit.title = title
        habit.habitDescription = description
        habit.isScheduled = isScheduled
        habit.scheduledDate = scheduledDate
        habit.scheduledTime = scheduledTime
        habit.duration = duration as NSNumber?
        habit.priority = Int16(priority)
        habit.dueDate = dueDate
        habit.reminder = reminder
        habit.tags = tags?.joined(separator: ",")
        habit.project = project
        habit.frequency = frequency.rawValue
        habit.streak = Int16(streak)
        habit.streakFreezeAvailable = streakFreezeAvailable
        habit.goal = goal as NSNumber?
        habit.goalProgress = goalProgress
        habit.notes = notes
        habit.specificDays = specificDays?.map { String($0) }?.joined(separator: ",")

        try saveContext()
    }

    func deleteHabit(_ habit: HabitEntity) throws {
        viewContext.delete(habit)
        try saveContext()
    }

    // Scheduleables
    func loadScheduleables() throws -> [AnyScheduleable] {
        var scheduleables: [AnyScheduleable] = []
        let tasks = try fetchTasks().map { $0.toTask() }
        let habits = try fetchHabits().map { $0.toHabit() }
        scheduleables.append(contentsOf: tasks)
        scheduleables.append(contentsOf: habits)
        return scheduleables
    }
    
    // Fixed Routines
    func fetchFixedRoutines() throws -> [FixedRoutineEntity] {
        let fetchRequest: NSFetchRequest<FixedRoutineEntity> = FixedRoutineEntity.fetchRequest()
        return try viewContext.fetch(fetchRequest)
    }

    func saveFixedRoutine(title: String, description: String?, startTime: Date?, flexibility: TimeInterval?, recurrence: FixedRoutine.Recurrence, tasks: [TaskEntity]) throws {
        let fixedRoutine = FixedRoutineEntity(context: viewContext)
        fixedRoutine.id = UUID()
        fixedRoutine.title = title
        fixedRoutine.routineDescription = description
        fixedRoutine.startTime = startTime
        fixedRoutine.flexibility = flexibility as NSNumber?
        fixedRoutine.recurrence = recurrence.rawValue
        fixedRoutine.addToTasks(NSSet(array: tasks))

        try saveContext()
    }

    func updateFixedRoutine(_ fixedRoutine: FixedRoutineEntity, title: String, description: String?, startTime: Date?, flexibility: TimeInterval?, recurrence: FixedRoutine.Recurrence, tasks: [TaskEntity]) throws {
        fixedRoutine.title = title
        fixedRoutine.routineDescription = description
        fixedRoutine.startTime = startTime
        fixedRoutine.flexibility = flexibility as NSNumber?
        fixedRoutine.recurrence = recurrence.rawValue

        // Remove existing tasks
        if let existingTasks = fixedRoutine.tasks?.allObjects as? [TaskEntity] {
            for task in existingTasks {
                fixedRoutine.removeFromTasks(task)
            }
        }

        // Add new tasks
        fixedRoutine.addToTasks(NSSet(array: tasks))

        try saveContext()
    }

    func deleteFixedRoutine(_ fixedRoutine: FixedRoutineEntity) throws {
        viewContext.delete(fixedRoutine)
        try saveContext()
    }

    // MARK: - Core Data Saving support

    func saveContext() throws {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                self.error = IdentifiableError(error: error)
                throw DataManagerError.dataPersistenceError(error)
            }
        }
    }
}

// Identifiable Error Wrapper
struct IdentifiableError: Identifiable, Error {
    let id = UUID()
    let error: Error
}

// DataManagerError enum
enum DataManagerError: Error {
    case dataPersistenceError(Error)
}
