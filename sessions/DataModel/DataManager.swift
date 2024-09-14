import CoreData

class DataManager: ObservableObject {
    
    @Published var error: Error?
    
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
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Error Handling
    
    enum DataManagerError: Error {
        case invalidData
        case dataPersistenceError(Error)
    }
    
    // MARK: - Scheduleable
    
    func saveScheduleable(scheduleable: Scheduleable) throws {
        // Data validation before saving (example)
        guard !scheduleable.title.isEmpty else {
            throw DataManagerError.invalidData
        }
        
        if let task = scheduleable as? Task {
            let taskEntity = getTaskEntity(for: task) ?? TaskEntity(context: context)
            taskEntity.id = task.id
            taskEntity.title = task.title
            taskEntity.taskDescription = task.description
            taskEntity.isScheduled = task.isScheduled
            taskEntity.scheduledDate = task.scheduledDate
            taskEntity.scheduledTime = task.scheduledTime
            taskEntity.duration = task.duration as? NSNumber
            taskEntity.priority = Int16(task.priority)
            taskEntity.dueDate = task.dueDate
            taskEntity.reminder = task.reminder
            taskEntity.tags = task.tags?.joined(separator: ",")
            taskEntity.project = task.project
            taskEntity.status = task.status.rawValue
        } else if let habit = scheduleable as? Habit {
            let habitEntity = getHabitEntity(for: habit) ?? HabitEntity(context: context)
            habitEntity.id = habit.id
            habitEntity.title = habit.title
            habitEntity.habitDescription = habit.description
            habitEntity.isScheduled = habit.isScheduled
            habitEntity.scheduledDate = habit.scheduledDate
            habitEntity.scheduledTime = habit.scheduledTime
            habitEntity.duration = habit.duration as? NSNumber
            habitEntity.priority = Int16(habit.priority)
            habitEntity.dueDate = habit.dueDate
            habitEntity.reminder = habit.reminder
            habitEntity.tags = habit.tags?.joined(separator: ",")
            habitEntity.project = habit.project
            habitEntity.frequency = habit.frequency.rawValue
            habitEntity.streak = Int16(habit.streak)
            habitEntity.streakFreezeAvailable = habit.streakFreezeAvailable
            habitEntity.goal = habit.goal as? NSNumber
            habitEntity.goalProgress = habit.goalProgress as? NSNumber
            habitEntity.notes = habit.notes
            habitEntity.specificDays = habit.specificDays?.map { String($0) }?.joined(separator: ",")
        }
        
        do {
            try context.save()
        } catch {
            throw DataManagerError.dataPersistenceError(error)
        }
    }
    
    func loadScheduleables() -> [Scheduleable] {
        let taskFetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        let habitFetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        
        do {
            let tasks = try context.fetch(taskFetchRequest).map { $0.toTask() }
            let habits = try context.fetch(habitFetchRequest).map { $0.toHabit() }
            return tasks + habits
        } catch {
            print("Error loading scheduleables: \(error)")
            return []
        }
    }
    
    func deleteScheduleable(scheduleable: Scheduleable) {
        if let task = scheduleable as? Task, let taskEntity = getTaskEntity(for: task) {
            context.delete(taskEntity)
        } else if let habit = scheduleable as? Habit, let habitEntity = getHabitEntity(for: habit) {
            context.delete(habitEntity)
        }
        
        saveContext()
    }
    
    // MARK: - Task
    
    func saveTask(task: Task) throws {
        try saveScheduleable(scheduleable: task)
    }
    
    func loadTasks() -> [Task] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        
        do {
            return try context.fetch(fetchRequest).map { $0.toTask() }
        } catch {
            print("Error loading tasks: \(error)")
            return []
        }
    }
    
    // MARK: - Habit
    
    func saveHabit(habit: Habit) throws {
        try saveScheduleable(scheduleable: habit)
    }
    
    func loadHabits() -> [Habit] {
        let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        
        do {
            return try context.fetch(fetchRequest).map { $0.toHabit() }
        } catch {
            print("Error loading habits: \(error)")
            return []
        }
    }
    
    // MARK: - FixedRoutine
    
    func saveFixedRoutine(fixedRoutine: FixedRoutine) throws {
        let routineEntity = getFixedRoutineEntity(for: fixedRoutine) ?? FixedRoutineEntity(context: context)
        routineEntity.id = fixedRoutine.id
        routineEntity.title = fixedRoutine.title
        routineEntity.routineDescription = fixedRoutine.description
        routineEntity.startTime = fixedRoutine.startTime
        routineEntity.flexibility = fixedRoutine.flexibility as? NSNumber
        routineEntity.recurrence = fixedRoutine.recurrence.rawValue
        
        // Delete existing tasks for this routine
        if let existingTasks = routineEntity.tasks?.allObjects as? [TaskEntity] {
            for task in existingTasks {
                context.delete(task)
            }
        }
        
        // Add new tasks
        for task in fixedRoutine.tasks {
            let taskEntity = TaskEntity(context: context)
            taskEntity.id = task.id
            taskEntity.title = task.title
            taskEntity.taskDescription = task.description
            taskEntity.duration = task.duration as? NSNumber
            routineEntity.addToTasks(taskEntity)
        }
        
        do {
            try context.save()
        } catch {
            throw DataManagerError.dataPersistenceError(error)
        }
    }
    
    func loadFixedRoutine(withID id: UUID) -> FixedRoutine? {
        let fetchRequest: NSFetchRequest<FixedRoutineEntity> = FixedRoutineEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let routineEntity = try context.fetch(fetchRequest).first {
                return routineEntity.toFixedRoutine()
            }
        } catch {
            print("Error loading fixed routine: \(error)")
        }
        return nil
    }
    
    func loadAllFixedRoutines() -> [FixedRoutine] {
        let fetchRequest: NSFetchRequest<FixedRoutineEntity> = FixedRoutineEntity.fetchRequest()
        
        do {
            return try context.fetch(fetchRequest).map { $0.toFixedRoutine() }
        } catch {
            print("Error loading fixed routines: \(error)")
            return []
        }
    }
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Background Tasks

    private func performBackgroundTask(block: @escaping () -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    // Background data synchronization using CloudKit
    func syncDataInBackground() {
        performBackgroundTask {
            let privateDatabase = CKContainer.default().privateCloudDatabase
            
            // 1. Sync Tasks
            syncTasks(with: privateDatabase) { taskSyncResult in
                switch taskSyncResult {
                case .success:
                    print("Tasks synced successfully.")
                case .failure(let error):
                    print("Error syncing tasks: \(error.localizedDescription)")
                }
                
                // 2. Sync Habits (after tasks are synced)
                self.syncHabits(with: privateDatabase) { habitSyncResult in
                    switch habitSyncResult {
                    case .success:
                        print("Habits synced successfully.")
                    case .failure(let error):
                        print("Error syncing habits: \(error.localizedDescription)")
                    }
                    
                    // 3. Sync Fixed Routines (after habits are synced)
                    self.syncFixedRoutines(with: privateDatabase) { fixedRoutineSyncResult in
                        switch fixedRoutineSyncResult {
                        case .success:
                            print("Fixed routines synced successfully.")
                        case .failure(let error):
                            print("Error syncing fixed routines: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - CloudKit Synchronization Helpers

    private func syncTasks(with database: CKDatabase, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Fetch tasks from Core Data
        let tasks = loadTasks()

        // 2. Create CloudKit records for new tasks
        var newTaskRecords: [CKRecord] = []
        for task in tasks where task.cloudKitRecordID == nil {
            let taskRecord = createTaskRecord(from: task)
            newTaskRecords.append(taskRecord)
        }

        // 3. Save new task records to CloudKit
        let saveNewRecordsOperation = CKModifyRecordsOperation(recordsToSave: newTaskRecords, recordIDsToDelete: nil)
        saveNewRecordsOperation.savePolicy = .changedKeys
        saveNewRecordsOperation.perRecordCompletionBlock = { record, error in
            if let error = error {
                print("Error saving task record: \(error.localizedDescription)")
            } else {
                // Update Core Data with CloudKit record ID
                DispatchQueue.main.async {
                    if let task = tasks.first(where: { $0.title == record["title"] as? String }) {
                        task.cloudKitRecordID = record.recordID
                        try? self.saveTask(task: task)
                    }
                }
            }
        }
        saveNewRecordsOperation.modifyRecordsCompletionBlock = { _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // 4. Fetch changes from CloudKit
            self.fetchTaskChanges(with: database) { result in
                switch result {
                case .success(let changes):
                    // 5. Apply changes to Core Data
                    self.applyTaskChanges(changes)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        database.add(saveNewRecordsOperation)
    }

    private func fetchTaskChanges(with database: CKDatabase, completion: @escaping (Result<([CKRecord], [CKRecord.ID]), Error>) -> Void) {
        let changeTokenKey = "CloudKitTaskChangeToken"
        let changeToken = UserDefaults.standard.data(forKey: changeTokenKey)

        let fetchChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken != nil ? CKServerChangeToken(data: changeToken!) : nil)
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        fetchChangesOperation.recordZoneWithIDChangedBlock = { zoneID in
            // Handle changes to specific record zones if needed
        }

        fetchChangesOperation.recordZoneWithIDWasDeletedBlock = { zoneID in
            // Handle deleted record zones if needed
        }

        fetchChangesOperation.changeTokenUpdatedBlock = { newToken in
            UserDefaults.standard.set(newToken.data, forKey: changeTokenKey)
        }

        fetchChangesOperation.fetchDatabaseChangesCompletionBlock = { newToken, moreComing, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            UserDefaults.standard.set(newToken.data, forKey: changeTokenKey)

            if moreComing {
                // More changes are coming, fetch them recursively
                self.fetchTaskChanges(with: database, completion: completion)
            } else {
                completion(.success((changedRecords, deletedRecordIDs)))
            }
        }

        fetchChangesOperation.recordChangedBlock = { record in
            changedRecords.append(record)
        }

        fetchChangesOperation.recordWithIDWasDeletedBlock = { recordID, recordType in
            deletedRecordIDs.append(recordID)
        }

        database.add(fetchChangesOperation)
    }

    private func applyTaskChanges(_ changes: ([CKRecord], [CKRecord.ID])) {
        let (changedRecords, deletedRecordIDs) = changes
        
        // Update existing tasks
        for changedRecord in changedRecords {
            if let existingTask = loadTasks().first(where: { $0.cloudKitRecordID == changedRecord.recordID }) {
                updateTask(from: changedRecord, to: existingTask)
            } else {
                // Create a new task if it doesn't exist locally
                let newTask = Task(id: UUID(), title: changedRecord["title"] as? String ?? "", description: changedRecord["taskDescription"] as? String, isScheduled: changedRecord["isScheduled"] as? Bool ?? false, scheduledDate: changedRecord["scheduledDate"] as? Date, scheduledTime: changedRecord["scheduledTime"] as? Date, duration: changedRecord["duration"] as? TimeInterval, priority: changedRecord["priority"] as? Int ?? 2, dueDate: changedRecord["dueDate"] as? Date, reminder: changedRecord["reminder"] as? Date, tags: (changedRecord["tags"] as? String)?.components(separatedBy: ","), project: changedRecord["project"] as? String, status: Task.TaskStatus(rawValue: changedRecord["status"] as? String ?? "") ?? .notStarted)
                newTask.cloudKitRecordID = changedRecord.recordID
                try? saveTask(task: newTask)
            }
        }

        // Delete tasks
        for deletedRecordID in deletedRecordIDs {
            if let taskToDelete = loadTasks().first(where: { $0.cloudKitRecordID == deletedRecordID }) {
                deleteScheduleable(scheduleable: taskToDelete)
            }
        }

        saveContext()
    }

    private func updateTask(from record: CKRecord, to task: Task) {
        task.title = record["title"] as? String ?? ""
        task.description = record["taskDescription"] as? String
        task.isScheduled = record["isScheduled"] as? Bool ?? false
        task.scheduledDate = record["scheduledDate"] as? Date
        task.scheduledTime = record["scheduledTime"] as? Date
        task.duration = record["duration"] as? TimeInterval
        task.priority = record["priority"] as? Int ?? 2
        task.dueDate = record["dueDate"] as? Date
        task.reminder = record["reminder"] as? Date
        task.tags = (record["tags"] as? String)?.components(separatedBy: ",")
        task.project = record["project"] as? String
        task.status = Task.TaskStatus(rawValue: record["status"] as? String ?? "") ?? .notStarted
    }

    private func createTaskRecord(from task: Task) -> CKRecord {
        let taskRecord = CKRecord(recordType: "Task")
        taskRecord["title"] = task.title as CKRecordValue
        taskRecord["taskDescription"] = task.description as CKRecordValue
        taskRecord["isScheduled"] = task.isScheduled as CKRecordValue
        taskRecord["scheduledDate"] = task.scheduledDate as CKRecordValue
        taskRecord["scheduledTime"] = task.scheduledTime as? CKRecordValue
        taskRecord["duration"] = task.duration as? CKRecordValue
        taskRecord["priority"] = task.priority as CKRecordValue
        taskRecord["dueDate"] = task.dueDate as CKRecordValue
        taskRecord["reminder"] = task.reminder as CKRecordValue
        taskRecord["tags"] = task.tags?.joined(separator: ",") as CKRecordValue
        taskRecord["project"] = task.project as CKRecordValue
        taskRecord["status"] = task.status.rawValue as CKRecordValue
        return taskRecord
    }

    private func syncHabits(with database: CKDatabase, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Fetch habits from Core Data
        let habits = loadHabits()

        // 2. Create CloudKit records for new habits
        var newHabitRecords: [CKRecord] = []
        for habit in habits where habit.cloudKitRecordID == nil {
            let habitRecord = createHabitRecord(from: habit)
            newHabitRecords.append(habitRecord)
        }

        // 3. Save new habit records to CloudKit
        let saveNewRecordsOperation = CKModifyRecordsOperation(recordsToSave: newHabitRecords, recordIDsToDelete: nil)
        saveNewRecordsOperation.savePolicy = .changedKeys
        saveNewRecordsOperation.perRecordCompletionBlock = { record, error in
            if let error = error {
                print("Error saving habit record: \(error.localizedDescription)")
            } else {
                // Update Core Data with CloudKit record ID
                DispatchQueue.main.async {
                    if let habit = habits.first(where: { $0.title == record["title"] as? String }) {
                        habit.cloudKitRecordID = record.recordID
                        try? self.saveHabit(habit: habit)
                    }
                }
            }
        }
        saveNewRecordsOperation.modifyRecordsCompletionBlock = { _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // 4. Fetch changes from CloudKit
            self.fetchHabitChanges(with: database) { result in
                switch result {
                case .success(let changes):
                    // 5. Apply changes to Core Data
                    self.applyHabitChanges(changes)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        database.add(saveNewRecordsOperation)
    }

    private func fetchHabitChanges(with database: CKDatabase, completion: @escaping (Result<([CKRecord], [CKRecord.ID]), Error>) -> Void) {
        let changeTokenKey = "CloudKitHabitChangeToken"
        let changeToken = UserDefaults.standard.data(forKey: changeTokenKey)

        let fetchChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken != nil ? CKServerChangeToken(data: changeToken!) : nil)
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        fetchChangesOperation.recordZoneWithIDChangedBlock = { zoneID in
            // Handle changes to specific record zones if needed
        }

        fetchChangesOperation.recordZoneWithIDWasDeletedBlock = { zoneID in
            // Handle deleted record zones if needed
        }

        fetchChangesOperation.changeTokenUpdatedBlock = { newToken in
            UserDefaults.standard.set(newToken.data, forKey: changeTokenKey)
        }

        fetchChangesOperation.fetchDatabaseChangesCompletionBlock = { newToken, moreComing, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            UserDefaults.standard.set(newToken.data, forKey: changeTokenKey)

            if moreComing {
                // More changes are coming, fetch them recursively
                self.fetchHabitChanges(with: database, completion: completion)
            } else {
                completion(.success((changedRecords, deletedRecordIDs)))
            }
        }

        fetchChangesOperation.recordChangedBlock = { record in
            changedRecords.append(record)
        }

        fetchChangesOperation.recordWithIDWasDeletedBlock = { recordID, recordType in
            deletedRecordIDs.append(recordID)
        }

        database.add(fetchChangesOperation)
    }

    private func applyHabitChanges(_ changes: ([CKRecord], [CKRecord.ID])) {
        let (changedRecords, deletedRecordIDs) = changes

        // Update existing habits
        for changedRecord in changedRecords {
            if let existingHabit = loadHabits().first(where: { $0.cloudKitRecordID == changedRecord.recordID }) {
                updateHabit(from: changedRecord, to: existingHabit)
            } else {
                // Create a new habit if it doesn't exist locally
                let newHabit = Habit(id: UUID(), title: changedRecord["title"] as? String ?? "", description: changedRecord["habitDescription"] as? String, isScheduled: changedRecord["isScheduled"] as? Bool ?? false, scheduledDate: changedRecord["scheduledDate"] as? Date, scheduledTime: changedRecord["scheduledTime"] as? Date, duration: changedRecord["duration"] as? TimeInterval, priority: changedRecord["priority"] as? Int ?? 2, dueDate: changedRecord["dueDate"] as? Date, reminder: changedRecord["reminder"] as? Date, tags: (changedRecord["tags"] as? String)?.components(separatedBy: ","), project: changedRecord["project"] as? String, frequency: Habit.HabitFrequency(rawValue: changedRecord["frequency"] as? String ?? "") ?? .daily)
                newHabit.cloudKitRecordID = changedRecord.recordID
                newHabit.streak = changedRecord["streak"] as? Int ?? 0
                newHabit.streakFreezeAvailable = changedRecord["streakFreezeAvailable"] as? Bool ?? true
                newHabit.goal = changedRecord["goal"] as? Double
                newHabit.goalProgress = changedRecord["goalProgress"] as? Double ?? 0.0
                newHabit.notes = changedRecord["notes"] as? String
                newHabit.specificDays = (changedRecord["specificDays"] as? String)?.components(separatedBy: ",").compactMap { Int($0) }
                try? saveHabit(habit: newHabit)
            }
        }

        // Delete habits
        for deletedRecordID in deletedRecordIDs {
            if let habitToDelete = loadHabits().first(where: { $0.cloudKitRecordID == deletedRecordID }) {
                deleteScheduleable(scheduleable: habitToDelete)
            }
        }

        saveContext()
    }

    private func updateHabit(from record: CKRecord, to habit: Habit) {
        habit.title = record["title"] as? String ?? ""
        habit.description = record["habitDescription"] as? String
        habit.isScheduled = record["isScheduled"] as? Bool ?? false
        habit.scheduledDate = record["scheduledDate"] as? Date
        habit.scheduledTime = record["scheduledTime"] as? Date
        habit.duration = record["duration"] as? TimeInterval
        habit.priority = record["priority"] as? Int ?? 2
        habit.dueDate = record["dueDate"] as? Date
        habit.reminder = record["reminder"] as? Date
        habit.tags = (record["tags"] as? String)?.components(separatedBy: ",")
        habit.project = record["project"] as? String
        habit.frequency = Habit.HabitFrequency(rawValue: record["frequency"] as? String ?? "") ?? .daily
        habit.streak = record["streak"] as? Int ?? 0
        habit.streakFreezeAvailable = record["streakFreezeAvailable"] as? Bool ?? true
        habit.goal = record["goal"] as? Double
        habit.goalProgress = record["goalProgress"] as? Double ?? 0.0
        habit.notes = record["notes"] as? String
        habit.specificDays = (record["specificDays"] as? String)?.components(separatedBy: ",").compactMap { Int($0) }
    }

    private func createHabitRecord(from habit: Habit) -> CKRecord {
        let habitRecord = CKRecord(recordType: "Habit")
        habitRecord["title"] = habit.title as CKRecordValue
        habitRecord["habitDescription"] = habit.description as CKRecordValue
        habitRecord["isScheduled"] = habit.isScheduled as CKRecordValue
        habitRecord["scheduledDate"] = habit.scheduledDate as CKRecordValue
        habitRecord["scheduledTime"] = habit.scheduledTime as? CKRecordValue
        habitRecord["duration"] = habit.duration as? CKRecordValue
        habitRecord["priority"] = habit.priority as CKRecordValue
        habitRecord["dueDate"] = habit.dueDate as CKRecordValue
        habitRecord["reminder"] = habit.reminder as CKRecordValue
        habitRecord["tags"] = habit.tags?.joined(separator: ",") as CKRecordValue
        habitRecord["project"] = habit.project as CKRecordValue
        habitRecord["frequency"] = habit.frequency.rawValue as CKRecordValue
        habitRecord["streak"] = habit.streak as CKRecordValue
        habitRecord["streakFreezeAvailable"] = habit.streakFreezeAvailable as CKRecordValue
        habitRecord["goal"] = habit.goal as? CKRecordValue
        habitRecord["goalProgress"] = habit.goalProgress as CKRecordValue
        habitRecord["notes"] = habit.notes as CKRecordValue
        habitRecord["specificDays"] = habit.specificDays?.map { String($0) }?.joined(separator: ",") as CKRecordValue
        return habitRecord
    }

    private func syncFixedRoutines(with database: CKDatabase, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Fetch fixed routines from Core Data
        let fixedRoutines = loadAllFixedRoutines()

        // 2. Create CloudKit records for new fixed routines
        var newFixedRoutineRecords: [CKRecord] = []
        for fixedRoutine in fixedRoutines where fixedRoutine.cloudKitRecordID == nil {
            let fixedRoutineRecord = createFixedRoutineRecord(from: fixedRoutine)
            newFixedRoutineRecords.append(fixedRoutineRecord)
        }

        // 3. Save new fixed routine records to CloudKit
        let saveNewRecordsOperation = CKModifyRecordsOperation(recordsToSave: newFixedRoutineRecords, recordIDsToDelete: nil)
        saveNewRecordsOperation.savePolicy = .changedKeys
        saveNewRecordsOperation.perRecordCompletionBlock = { record, error in
            if let error = error {
                print("Error saving fixed routine record: \(error.localizedDescription)")
            } else {
                // Update Core Data with CloudKit record ID
                DispatchQueue.main.async {
                    if let fixedRoutine = fixedRoutines.first(where: { $0.title == record["title"] as? String }) {
                        fixedRoutine.cloudKitRecordID = record.recordID
                        try? self.saveFixedRoutine(fixedRoutine: fixedRoutine)
                    }
                }
            }
        }
        saveNewRecordsOperation.modifyRecordsCompletionBlock = { _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // 4. Fetch changes from CloudKit
            self.fetchFixedRoutineChanges(with: database) { result in
                switch result {
                case .success(let changes):
                    // 5. Apply changes to Core Data
                    self.applyFixedRoutineChanges(changes)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        database.add(saveNewRecordsOperation)
    }

    private func fetchFixedRoutineChanges(with database: CKDatabase, completion: @escaping (Result<([CKRecord], [CKRecord.ID]), Error>) -> Void) {
        let changeTokenKey = "CloudKitFixedRoutineChangeToken"
        let changeToken = UserDefaults.standard.data(forKey: changeTokenKey)

        let fetchChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken != nil ? CKServerChangeToken(data: changeToken!) : nil)
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        fetchChangesOperation.recordZoneWithIDChangedBlock = { zoneID in
            // Handle changes to specific record zones if needed
        }

        fetchChangesOperation.recordZoneWithIDWasDeletedBlock = { zoneID in
            // Handle deleted record zones if needed
        }

        fetchChangesOperation.changeTokenUpdatedBlock = { newToken in
            UserDefaults.standard.set(newToken.data, forKey: changeTokenKey)
        }

        fetchChangesOperation.fetchDatabaseChangesCompletionBlock = { newToken, moreComing, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            UserDefaults.standard.set(newToken.data, forKey: changeTokenKey)

            if moreComing {
                // More changes are coming, fetch them recursively
                self.fetchFixedRoutineChanges(with: database, completion: completion)
            } else {
                completion(.success((changedRecords, deletedRecordIDs)))
            }
        }

        fetchChangesOperation.recordChangedBlock = { record in
            changedRecords.append(record)
        }

        fetchChangesOperation.recordWithIDWasDeletedBlock = { recordID, recordType in
            deletedRecordIDs.append(recordID)
        }

        database.add(fetchChangesOperation)
    }

    private func applyFixedRoutineChanges(_ changes: ([CKRecord], [CKRecord.ID])) {
        let (changedRecords, deletedRecordIDs) = changes

        // Update existing fixed routines
        for changedRecord in changedRecords {
            if let existingFixedRoutine = loadAllFixedRoutines().first(where: { $0.cloudKitRecordID == changedRecord.recordID }) {
                updateFixedRoutine(from: changedRecord, to: existingFixedRoutine)
            } else {
                // Create a new fixed routine if it doesn't exist locally
                let newFixedRoutine = FixedRoutine(id: UUID(), title: changedRecord["title"] as? String ?? "", description: changedRecord["routineDescription"] as? String, tasks: [], recurrence: FixedRoutine.Recurrence(rawValue: changedRecord["recurrence"] as? String ?? "") ?? .daily, startTime: changedRecord["startTime"] as? Date, flexibility: changedRecord["flexibility"] as? TimeInterval)
                newFixedRoutine.cloudKitRecordID = changedRecord.recordID
                try? saveFixedRoutine(fixedRoutine: newFixedRoutine)
            }
        }

        // Delete fixed routines
        for deletedRecordID in deletedRecordIDs {
            if let fixedRoutineToDelete = loadAllFixedRoutines().first(where: { $0.cloudKitRecordID == deletedRecordID }) {
                // Delete the fixed routine from Core Data
                if let routineEntity = getFixedRoutineEntity(for: fixedRoutineToDelete) {
                    context.delete(routineEntity)
                }
            }
        }

        saveContext()
    }

    private func updateFixedRoutine(from record: CKRecord, to fixedRoutine: FixedRoutine) {
        fixedRoutine.title = record["title"] as? String ?? ""
        fixedRoutine.description = record["routineDescription"] as? String
        fixedRoutine.startTime = record["startTime"] as? Date
        fixedRoutine.flexibility = record["flexibility"] as? TimeInterval
        fixedRoutine.recurrence = FixedRoutine.Recurrence(rawValue: record["recurrence"] as? String ?? "") ?? .daily
        
        // Fetch tasks associated with this fixed routine from CloudKit
        let taskReferences = record["tasks"] as? [CKRecord.Reference] ?? []
        var fetchedTasks: [Task] = []
        let fetchTasksOperation = CKFetchRecordsOperation(recordIDs: taskReferences.map { $0.recordID })
        fetchTasksOperation.perRecordCompletionBlock = { record, _, error in
            if let error = error {
                print("Error fetching task record: \(error.localizedDescription)")
            } else if let taskRecord = record, let task = self.taskFromRecord(taskRecord) {
                fetchedTasks.append(task)
            }
        }
        fetchTasksOperation.fetchRecordsCompletionBlock = { _, error in
            if let error = error {
                print("Error fetching tasks: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    fixedRoutine.tasks = fetchedTasks
                    try? self.saveFixedRoutine(fixedRoutine: fixedRoutine)
                }
            }
        }
        CKContainer.default().privateCloudDatabase.add(fetchTasksOperation)
    }

    private func createFixedRoutineRecord(from fixedRoutine: FixedRoutine) -> CKRecord {
        let fixedRoutineRecord = CKRecord(recordType: "FixedRoutine")
        fixedRoutineRecord["title"] = fixedRoutine.title as CKRecordValue
        fixedRoutineRecord["routineDescription"] = fixedRoutine.description as CKRecordValue
        fixedRoutineRecord["startTime"] = fixedRoutine.startTime as CKRecordValue
        fixedRoutineRecord["flexibility"] = fixedRoutine.flexibility as? CKRecordValue
        fixedRoutineRecord["recurrence"] = fixedRoutine.recurrence.rawValue as CKRecordValue

        // Create references to tasks associated with this fixed routine
        var taskReferences: [CKRecord.Reference] = []
        for task in fixedRoutine.tasks {
            if let taskRecordID = task.cloudKitRecordID {
                let taskReference = CKRecord.Reference(recordID: taskRecordID, action: .deleteSelf)
                taskReferences.append(taskReference)
            }
        }
        fixedRoutineRecord["tasks"] = taskReferences as CKRecordValue

        return fixedRoutineRecord
    }

    private func taskFromRecord(_ record: CKRecord) -> Task? {
        guard let title = record["title"] as? String,
              let statusRawValue = record["status"] as? String,
              let status = Task.TaskStatus(rawValue: statusRawValue) else {
            return nil
        }

        return Task(id: record.recordID.recordName.uuid,
                    title: title,
                    description: record["taskDescription"] as? String,
                    isScheduled: record["isScheduled"] as? Bool ?? false,
                    scheduledDate: record["scheduledDate"] as? Date,
                    scheduledTime: record["scheduledTime"] as? Date,
                    duration: record["duration"] as? TimeInterval,
                    priority: record["priority"] as? Int ?? 2,
                    dueDate: record["dueDate"] as? Date,
                    reminder: record["reminder"] as? Date,
                    tags: (record["tags"] as? String)?.components(separatedBy: ","),
                    project: record["project"] as? String,
                    status: status)
    }
    
    // MARK: - Helper Methods
    
    private func getTaskEntity(for task: Task) -> TaskEntity? {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
        
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching TaskEntity: \(error)")
            return nil
        }
    }
    
    private func getHabitEntity(for habit: Habit) -> HabitEntity? {
        let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", habit.id as CVarArg)
        
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching HabitEntity: \(error)")
            return nil
        }
    }
    
    private func getFixedRoutineEntity(for fixedRoutine: FixedRoutine) -> FixedRoutineEntity? {
        let fetchRequest: NSFetchRequest<FixedRoutineEntity> = FixedRoutineEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", fixedRoutine.id as CVarArg)
        
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching FixedRoutineEntity: \(error)")
            return nil
        }
    }
}

// Extensions for converting between Core Data entities and model objects
extension TaskEntity {
    func toTask() -> Task {
        return Task(id: self.id ?? UUID(),
                    title: self.title ?? "",
                    description: self.taskDescription,
                    isScheduled: self.isScheduled,
                    scheduledDate: self.scheduledDate,
                    scheduledTime: self.scheduledTime,
                    duration: self.duration?.doubleValue,
                    priority: Int(self.priority),
                    dueDate: self.dueDate,
                    reminder: self.reminder,
                    tags: self.tags?.components(separatedBy: ","),
                    project: self.project,
                    status: Task.TaskStatus(rawValue: self.status ?? "") ?? .notStarted)
    }
}

extension HabitEntity {
    func toHabit() -> Habit {
        let habit = Habit(id: self.id ?? UUID(),
                          title: self.title ?? "",
                          description: self.habitDescription,
                          isScheduled: self.isScheduled,
                          scheduledDate: self.scheduledDate,
                          scheduledTime: self.scheduledTime,
                          duration: self.duration?.doubleValue,
                          priority: Int(self.priority),
                          dueDate: self.dueDate,
                          reminder: self.reminder,
                          tags: self.tags?.components(separatedBy: ","),
                          project: self.project,
                          frequency: Habit.HabitFrequency(rawValue: self.frequency ?? "") ?? .daily)
        habit.streak = Int(self.streak)
        habit.streakFreezeAvailable = self.streakFreezeAvailable
        habit.goal = self.goal?.doubleValue
        habit.goalProgress = self.goalProgress?.doubleValue ?? 0.0
        habit.notes = self.notes
        habit.specificDays = self.specificDays?.components(separatedBy: ",").compactMap { Int($0) }
        return habit
    }
}

extension FixedRoutineEntity {
    func toFixedRoutine() -> FixedRoutine {
        let tasks = (self.tasks?.allObjects as? [TaskEntity])?.map { $0.toTask() } ?? []
        return FixedRoutine(id: self.id ?? UUID(),
                            title: self.title ?? "",
                            description: self.routineDescription,
                            tasks: tasks,
                            recurrence: FixedRoutine.Recurrence(rawValue: self.recurrence ?? "") ?? .daily,
                            startTime: self.startTime,
                            flexibility: self.flexibility?.doubleValue)
    }
}
