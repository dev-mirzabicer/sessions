import Foundation
import GoogleAPIClientForRESTCore
import GoogleAPIClientForREST_Calendar

protocol RoutineManagerDelegate: AnyObject {
    func routineManager(_ routineManager: RoutineManager, didFetchGoogleCalendarEvents events: [GTLRCalendar_Event])
}

class RoutineManager: ObservableObject {
    @Published var currentRoutine: Routine?
    @Published var scheduledItems: [Scheduleable] = []
    @Published var googleCalendarEvents: [GTLRCalendar_Event] = []
    @Published var fixedRoutines: [FixedRoutine] = []
    @Published var tasks: [Task] = []
    @Published var habits: [Habit] = []

    private let dataManager: DataManager
    private let calendarService: GTLRCalendarService

    enum RoutineManagerError: Error {
        case schedulingConflict(Scheduleable)
        case googleCalendarError(Error)
    }

    static let shared = RoutineManager(dataManager: DataManager(), calendarService: GTLRCalendarService())

    init(dataManager: DataManager, calendarService: GTLRCalendarService) {
        self.dataManager = dataManager
        self.calendarService = calendarService
        loadFixedRoutines()
        loadTasks()
        loadHabits()
    }

    func loadRoutine(for date: Date) {
        scheduledItems = dataManager.loadScheduleables().filter { scheduleable in
            guard let scheduledDate = scheduleable.scheduledDate else { return false }
            return Calendar.current.isDate(scheduledDate, inSameDayAs: date)
        }

        fetchGoogleCalendarEvents(for: date)

        currentRoutine = Routine(date: date, scheduledItems: scheduledItems)
    }

    func saveRoutine() {
        guard let currentRoutine = currentRoutine else { return }

        for item in currentRoutine.scheduledItems {
            do {
                try dataManager.saveScheduleable(scheduleable: item)
            } catch {
                print("Error saving scheduleable item: \(error)")
            }
        }
    }

    func scheduleItem(item: Scheduleable, date: Date, time: Date) throws {
        if let conflict = checkForConflicts(item: item, date: date, time: time) {
            throw RoutineManagerError.schedulingConflict(conflict)
        }

        do {
            try item.schedule(date: date, time: time)
        } catch {
            print("Error scheduling item: \(error)")
        }

        if let currentRoutine = currentRoutine, currentRoutine.date == date {
            currentRoutine.scheduledItems.append(item)
        }

        do {
            try dataManager.saveScheduleable(scheduleable: item)
        } catch {
            print("Error saving scheduleable item: \(error)")
        }
    }

    func rescheduleItem(item: Scheduleable, date: Date, time: Date) throws {
        if let currentRoutine = currentRoutine, let index = currentRoutine.scheduledItems.firstIndex(where: { $0.id == item.id }) {
            currentRoutine.scheduledItems.remove(at: index)
        }

        do {
            try item.reschedule(date: date, time: time)
        } catch {
            print("Error rescheduling item: \(error)")
        }

        if let currentRoutine = currentRoutine, currentRoutine.date == date {
            currentRoutine.scheduledItems.append(item)
        }

        do {
            try dataManager.saveScheduleable(scheduleable: item)
        } catch {
            print("Error saving scheduleable item: \(error)")
        }
    }

    func syncWithGoogleCalendar() {
        if let currentRoutine = currentRoutine {
            fetchGoogleCalendarEvents(for: currentRoutine.date)
        }
    }

    // MARK: - Google Calendar Integration

    private func fetchGoogleCalendarEvents(for date: Date) {
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: "primary")
        query.timeMin = GTLRDateTime(date: Calendar.current.startOfDay(for: date))
        query.timeMax = GTLRDateTime(date: Calendar.current.date(byAdding: .day, value: 1, to: date)!)

        calendarService.executeQuery(query) { (ticket, result, error) in
            if let error = error {
                print("Error fetching Google Calendar events: \(error)")
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

    func getRoutineItems(for date: Date) -> [Scheduleable] {
        var allItems: [Scheduleable] = []

        allItems.append(contentsOf: dataManager.loadScheduleables().filter { scheduleable in
            guard let scheduledDate = scheduleable.scheduledDate else { return false }
            return Calendar.current.isDate(scheduledDate, inSameDayAs: date)
        })

        for routine in fixedRoutines {
            if routine.shouldOccur(on: date) {
                allItems.append(contentsOf: routine.tasks)
            }
        }

        fetchGoogleCalendarEvents(for: date)
        allItems.append(contentsOf: googleCalendarEvents.map { event in
            return Task(title: event.summary ?? "Google Calendar Event",
                        description: event.descriptionProperty,
                        isScheduled: true,
                        scheduledDate: event.start?.dateTime?.date,
                        scheduledTime: event.start?.dateTime?.date,
                        duration: event.end?.dateTime?.date?.timeIntervalSince(event.start?.dateTime?.date ?? Date()))
        })

        return allItems
    }

    // MARK: - Fixed Routines

    private func loadFixedRoutines() {
        fixedRoutines = dataManager.loadAllFixedRoutines()
    }

    // MARK: - Tasks

    func loadTasks() {
        tasks = dataManager.loadTasks()
    }

    // MARK: - Habits

    func loadHabits() {
        habits = dataManager.loadHabits()
    }

    weak var delegate: RoutineManagerDelegate?
}

struct Routine {
    var date: Date
    var scheduledItems: [Scheduleable]
}
