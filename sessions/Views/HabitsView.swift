import SwiftUI

struct HabitsView: View {
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var isAddingHabit = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach($routineManager.habits) { $habit in
                        NavigationLink(destination: HabitDetailView(habit: $habit)) {
                            HabitRowView(habit: $habit)
                        }
                    }
                    .onDelete(perform: deleteHabit)
                }
                .listStyle(PlainListStyle())

                Button(action: {
                    isAddingHabit = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                .padding()
            }
            .navigationTitle("Habits")
            .sheet(isPresented: $isAddingHabit) {
                AddHabitView(isPresented: $isAddingHabit)
            }
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                routineManager.loadHabits()
            }
        }
    }

    func deleteHabit(at offsets: IndexSet) {
        if let index = offsets.first {
            let habitToDelete = routineManager.habits[index]
            routineManager.habits.remove(at: index)
            do {
                try routineManager.dataManager.deleteHabit(habitToDelete)
            } catch {
                routineManager.dataManager.error = error
            }
        }
    }
}

struct HabitRowView: View {
    @Binding var habit: HabitEntity
    @ObservedObject var routineManager = RoutineManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(habit.title ?? "")
                    .font(.headline)
                if let time = habit.scheduledTime {
                    Text("\(time, style: .time)")
                        .font(.subheadline)
                }
            }
            Spacer()
            Text("\(habit.streak)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(habit.streak > 0 ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(5)

            Button(action: {
                markHabitAsComplete()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }

    func markHabitAsComplete() {
        habit.streak += 1
        habit.streakFreezeAvailable = true
        if let goal = habit.goal {
            habit.goalProgress += 1
            if habit.goalProgress > goal.doubleValue {
                habit.goalProgress = goal.doubleValue // Prevent progress from exceeding the goal
            }
        }
        habit.scheduledDate = Date() // Update the last completion date

        // Schedule next occurrence based on frequency
        scheduleNextOccurrence(from: Date())

        do {
            try routineManager.dataManager.saveContext()
        } catch {
            routineManager.dataManager.error = error
        }
    }

    private func scheduleNextOccurrence(from date: Date) {
        guard let scheduledTime = habit.scheduledTime else { return }

        switch habit.frequency {
        case "Daily":
            if let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date) {
                habit.scheduledDate = nextDate
                habit.scheduledTime = scheduledTime
            }
        case "Weekly":
            if let nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: date) {
                habit.scheduledDate = nextDate
                habit.scheduledTime = scheduledTime
            }
        case "Specific Days":
            let calendar = Calendar.current
            let todayWeekday = calendar.component(.weekday, from: date)
            let specificDays = habit.specificDays?.components(separatedBy: ",").compactMap { Int($0) } ?? []

            guard !specificDays.isEmpty else { return }

            var nextWeekday = specificDays.first(where: { $0 > todayWeekday })
            if nextWeekday == nil {
                nextWeekday = specificDays.first
            }

            let daysToAdd = (nextWeekday! - todayWeekday + 7) % 7

            if let nextDate = calendar.current.date(byAdding: .day, value: daysToAdd, to: date) {
                habit.scheduledDate = nextDate
                habit.scheduledTime = scheduledTime
            }
        default:
            break
        }
    }
}

struct AddHabitView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description: String?
    @State private var scheduledTime = Date()
    @State private var duration: TimeInterval?
    @State private var priority = 2
    @State private var reminder: Date?
    @State private var tags: [String] = []
    @State private var project: String?
    @State private var frequency: Habit.HabitFrequency = .daily
    @State private var specificDays: [Int] = []
    @ObservedObject var routineManager = RoutineManager.shared

    var body: some View {
        NavigationView {
            Form {
                TextField("Title", text: $title)
                TextField("Description (Optional)", text: $description)
                DatePicker("Time", selection: $scheduledTime, displayedComponents: [.hourAndMinute])
                Stepper("Duration (minutes): \(Int(duration ?? 0))", value: $duration, in: 0...600, step: 5)
                Stepper("Priority: \(priority)", value: $priority, in: 1...3)
                DatePicker("Reminder (Optional)", selection: $reminder, displayedComponents: [.date, .hourAndMinute])
                TextField("Tags (comma-separated)", text: .constant(tags.joined(separator: ",")))
                    .onDisappear {
                        tags = $0.wrappedValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                TextField("Project (Optional)", text: $project)
                Picker("Frequency", selection: $frequency) {
                    ForEach(Habit.HabitFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }

                if frequency == .specificDays {
                    MultiSelectPicker(selectedItems: $specificDays,
                                          allItems: Array(1...7),
                                          itemFormatter: { "Day \($0)" })
                }

                Button(action: {
                    addHabit()
                }) {
                    Text("Add Habit")
                }
            }
            .navigationTitle("Add Habit")
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
            }
        }
    }

    func addHabit() {
        guard !title.isEmpty else {
            routineManager.dataManager.error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Please enter a title for the habit."])
            return
        }

        do {
            try routineManager.dataManager.saveHabit(title: title, description: description, isScheduled: true, scheduledDate: Date(), scheduledTime: scheduledTime, duration: duration, priority: priority, dueDate: nil, reminder: reminder, tags: tags, project: project, frequency: frequency, streak: 0, streakFreezeAvailable: true, goal: nil, goalProgress: 0.0, notes: nil, specificDays: specificDays)
            routineManager.loadHabits()
        } catch {
            routineManager.dataManager.error = error
        }

        presentationMode.wrappedValue.dismiss()
    }
}

struct HabitsView_Previews: PreviewProvider {
    static var previews: some View {
        HabitsView()
    }
}
