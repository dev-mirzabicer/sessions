import SwiftUI

struct HabitsView: View {
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var isAddingHabit = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(routineManager.habits) { habit in
                        NavigationLink(destination: HabitDetailView(habit: habit)) {
                            HabitRowView(habit: habit)
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
                AddHabitView(isPresented: $isAddingHabit, habits: $routineManager.habits)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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
                try routineManager.dataManager.deleteScheduleable(scheduleable: habitToDelete)
            } catch {
                alertMessage = "Error deleting habit: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

struct HabitRowView: View {
    @ObservedObject var habit: Habit
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(habit.title)
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
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    func markHabitAsComplete() {
        habit.markAsComplete(on: Date())
        if let index = routineManager.habits.firstIndex(where: { $0.id == habit.id }) {
            routineManager.habits[index] = habit
        }
        do {
            try routineManager.dataManager.saveHabit(habit: habit)
        } catch {
            alertMessage = "Error saving habit: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct AddHabitView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @Binding var habits: [Habit]
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
    @State private var showingAlert = false
    @State private var alertMessage = ""

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
                    .onAppear {
                        if let existingHabit = habits.first(where: { $0.title == title }) {
                            tags = existingHabit.tags ?? []
                        }
                    }
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
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    func addHabit() {
        guard !title.isEmpty else {
            alertMessage = "Please enter a title for the habit."
            showingAlert = true
            return
        }

        let newHabit = Habit(title: title, description: description, isScheduled: true, scheduledDate: Date(), scheduledTime: scheduledTime, duration: duration, priority: priority, reminder: reminder, tags: tags, project: project, frequency: frequency)
        newHabit.specificDays = specificDays
        habits.append(newHabit)
        do {
            try routineManager.dataManager.saveHabit(habit: newHabit)
        } catch {
            alertMessage = "Error saving habit: \(error.localizedDescription)"
            showingAlert = true
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct HabitsView_Previews: PreviewProvider {
    static var previews: some View {
        HabitsView()
    }
}
