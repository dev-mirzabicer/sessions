import Foundation
import GoogleAPIClientForREST
import GoogleSignIn

// RoutineManagerDelegate protocol (unchanged)
protocol RoutineManagerDelegate: AnyObject {
    func routineManager(_ routineManager: RoutineManager, didFetchGoogleCalendarEvents events: [GTLRCalendar_Event])
}

class RoutineManager: ObservableObject {
    @Published var currentRoutine: Routine?
    @Published var scheduledItems: [AnyScheduleable] = []
    @Published var googleCalendarEvents: [GTLRCalendar_Event] = []
    @Published var fixedRoutines: [FixedRoutineEntity] = []
    @Published var tasks: [TaskEntity] = []
    @Published var habits: [HabitEntity] = []

    private let dataManager: DataManager
    private let calendarService: GTLRCalendarService
    weak var delegate: RoutineManagerDelegate? // Add delegate property

    enum RoutineManagerError: Error {
        case schedulingConflict(Scheduleable)
        case googleCalendarError(Error)
        case googleSignInError(Error)
    }

    static let shared = RoutineManager(dataManager: DataManager(), calendarService: GTLRCalendarService())

    init(dataManager: DataManager, calendarService: GTLRCalendarService) {
        self.dataManager = dataManager
        self.calendarService = calendarService
        loadFixedRoutines()
        loadTasks()
        loadHabits()
    }

    // MARK: - Routine Management

    func loadRoutine(for date: Date) {
        do {
            let scheduleables = try dataManager.loadScheduleables()
            scheduledItems = scheduleables.filter { scheduleable in
                guard let scheduledDate = scheduleable.scheduledDate else { return false }
                return Calendar.current.isDate(scheduledDate, inSameDayAs: date)
            }.map { AnyScheduleable($0) } // Wrap in AnyScheduleable

            currentRoutine = Routine(date: date, scheduledItems: scheduledItems)
        } catch {
            dataManager.error = IdentifiableError(error: error)
        }
    }

    func saveRoutine() {
        do {
            try dataManager.saveContext()
        } catch {
            dataManager.error = IdentifiableError(error: error)
        }
    }

    func scheduleItem(item: Scheduleable, date: Date, time: Date) throws {
        if let conflict = checkForConflicts(item: item, date: date, time: time) {
            throw RoutineManagerError.schedulingConflict(conflict)
        }

        do {
            try item.schedule(date: date, time: time)

            if let currentRoutine = currentRoutine, currentRoutine.date == date {
                currentRoutine.scheduledItems.append(AnyScheduleable(item)) // Wrap in AnyScheduleable
            }

            try dataManager.saveScheduleable(scheduleable: item)
        } catch {
            dataManager.error = IdentifiableError(error: error)
            throw error
        }
    }

    func rescheduleItem(item: Scheduleable, date: Date, time: Date) throws {
        if let currentRoutine = currentRoutine, let index = currentRoutine.scheduledItems.firstIndex(where: { $0.id == item.id }) {
            currentRoutine.scheduledItems.remove(at: index)
        }

        do {
            try item.reschedule(date: date, time: time)

            if let currentRoutine = currentRoutine, currentRoutine.date == date {
                currentRoutine.scheduledItems.append(AnyScheduleable(item)) // Wrap in AnyScheduleable
            }

            try dataManager.saveScheduleable(scheduleable: item)
        } catch {
            dataManager.error = IdentifiableError(error: error)
            throw error
        }
    }

    // MARK: - Google Calendar Integration

    func syncWithGoogleCalendar() {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            // User is not signed in, initiate Google Sign-In
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
                    if let error = error {
                        self.dataManager.error = IdentifiableError(error: RoutineManagerError.googleSignInError(error))
                        return
                    }

                    guard let signInResult = signInResult else { return }

                    // User is signed in, fetch Google Calendar events
                    self.fetchGoogleCalendarEvents()
                }
            }
            return
        }

        // User is already signed in, fetch Google Calendar events
        fetchGoogleCalendarEvents()
    }

    private func fetchGoogleCalendarEvents() {
        if let currentRoutine = currentRoutine {
            fetchGoogleCalendarEvents(for: currentRoutine.date)
        }
    }

    private func fetchGoogleCalendarEvents(for date: Date) {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return }

        let calendarService = GTLRCalendarService()
        calendarService.authorizer = user.authentication.fetcherAuthorizer()

        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: "primary")
        query.timeMin = GTLRDateTime(date: Calendar.current.startOfDay(for: date))
        query.timeMax = GTLRDateTime(date: Calendar.current.date(byAdding: .day, value: 1, to: date)!)

        calendarService.executeQuery(query) { (ticket, result, error) in
            if let error = error {
                self.dataManager.error = RoutineManagerError.googleCalendarError(error)
                return
            }

            guard let eventsList = result as? GTLRCalendar_Events else {
                print("Invalid Google Calendar events result")
                return
            }

            DispatchQueue.main.async {
                self.googleCalendarEvents = eventsList.items ?? []
                self.delegate?.routineManager(self, didFetchGoogleCalendarEvents: self.googleCalendarEvents)
            }
        }
    }

    // MARK: - Conflict Detection

    private func checkForConflicts(item: Scheduleable, date: Date, time: Date) -> Scheduleable? {
        let newStartTime = time
        let newEndTime = time.addingTimeInterval(item.duration ?? 0)

        for scheduledItem in scheduledItems {
            if let scheduledDate = scheduledItem.scheduledDate,
               let scheduledTime = scheduledItem.scheduledTime,
               let duration = scheduledItem.duration,
               Calendar.current.isDate(scheduledDate, inSameDayAs: date) {

                let scheduledStartTime = scheduledTime
                let scheduledEndTime = scheduledTime.addingTimeInterval(duration)

                if newStartTime < scheduledEndTime && newEndTime > scheduledStartTime {
                    return scheduledItem
                }
            }
        }

        for event in googleCalendarEvents {
            if let startDateTime = event.start?.dateTime?.date,
               let endDateTime = event.end?.dateTime?.date,
               Calendar.current.isDate(date, inSameDayAs: startDateTime),
               newStartTime < endDateTime && newEndTime > startDateTime {
                let conflictingEvent = Task(title: event.summary ?? "Google Calendar Event",
                                           description: event.descriptionProperty,
                                           isScheduled: true,
                                           scheduledDate: startDateTime,
                                           scheduledTime: startDateTime,
                                           duration: endDateTime.timeIntervalSince(startDateTime))
                return conflictingEvent
            }
        }

        return nil
    }

    // MARK: - Data Loading

    func getRoutineItems(for date: Date) -> [AnyScheduleable] { // Return [AnyScheduleable]
        var allItems: [AnyScheduleable] = []

        do {
            let scheduleables = try dataManager.loadScheduleables()
            allItems.append(contentsOf: scheduleables.filter { scheduleable in
                guard let scheduledDate = scheduleable.scheduledDate else { return false }
                return Calendar.current.isDate(scheduledDate, inSameDayAs: date)
            }.map { AnyScheduleable($0) }) // Wrap in AnyScheduleable
        } catch {
            dataManager.error = IdentifiableError(error: error)
        }

        for routine in fixedRoutines {
            if routine.toFixedRoutine().shouldOccur(on: date) {
                allItems.append(contentsOf: (routine.tasks?.allObjects as? [TaskEntity] ?? []).map { AnyScheduleable($0.toTask()) }) // Wrap in AnyScheduleable
            }
        }

        fetchGoogleCalendarEvents(for: date)
        allItems.append(contentsOf: googleCalendarEvents.map { event in
            return AnyScheduleable(Task(title: event.summary ?? "Google Calendar Event",
                                        description: event.descriptionProperty,
                                        isScheduled: true,
                                        scheduledDate: event.start?.dateTime?.date,
                                        scheduledTime: event.start?.dateTime?.date,
                                        duration: event.end?.dateTime?.date?.timeIntervalSince(event.start?.dateTime?.date ?? Date()))) // Wrap in AnyScheduleable
        })

        return allItems
    }

    // MARK: - Fixed Routines

    private func loadFixedRoutines() {
        do {
            fixedRoutines = try dataManager.fetchFixedRoutines()
        } catch {
            dataManager.error = error
        }
    }

    // MARK: - Tasks

    func loadTasks() {
        do {
            tasks = try dataManager.fetchTasks()
        } catch {
            dataManager.error = error
        }
    }

    // MARK: - Habits

    func loadHabits() {
        do {
            habits = try dataManager.fetchHabits()
        } catch {
            dataManager.error = error
        }
    }
}

struct Routine {
    var date: Date
    var scheduledItems: [Scheduleable]
}
