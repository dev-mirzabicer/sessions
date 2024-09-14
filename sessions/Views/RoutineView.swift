import SwiftUI

struct RoutineView: View {
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var selectedDate = Date()
    @State private var isAddingNewItem = false

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                List {
                    ForEach(routineManager.getRoutineItems(for: selectedDate)) { item in
                        NavigationLink(destination: RoutineItemDetailView(item: item)) {
                            RoutineItemView(item: item)
                        }
                    }
                    .onDelete(perform: deleteRoutineItem)
                }
                .listStyle(PlainListStyle())

                Button(action: {
                    isAddingNewItem = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                .padding()
            }
            .navigationTitle("My Routine")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        routineManager.syncWithGoogleCalendar()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $isAddingNewItem) {
                AddNewItemView(isPresented: $isAddingNewItem, selectedDate: $selectedDate)
            }
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            routineManager.loadRoutine(for: selectedDate)
        }
    }

    func deleteRoutineItem(at offsets: IndexSet) {
        if let index = offsets.first {
            let itemToDelete = routineManager.getRoutineItems(for: selectedDate)[index]

            if let scheduleableIndex = routineManager.scheduledItems.firstIndex(where: { $0.id == itemToDelete.id }) {
                routineManager.scheduledItems.remove(at: scheduleableIndex)
            }

            if let task = itemToDelete as? TaskEntity {
                do {
                    try routineManager.dataManager.deleteTask(task)
                } catch {
                    routineManager.dataManager.error = error
                }
            } else if let habit = itemToDelete as? HabitEntity {
                do {
                    try routineManager.dataManager.deleteHabit(habit)
                } catch {
                    routineManager.dataManager.error = error
                }
            } else if let fixedRoutine = itemToDelete as? FixedRoutineEntity {
                do {
                    try routineManager.dataManager.deleteFixedRoutine(fixedRoutine)
                } catch {
                    routineManager.dataManager.error = error
                }
            }
        }
    }
}

struct RoutineItemView: View {
    var item: Scheduleable

    var body: some View {
        HStack {
            if let task = item as? Task {
                Image(systemName: "checkmark.square")
                    .foregroundColor(task.status == .done ? .green : .gray)
            } else if let habit = item as? Habit {
                Image(systemName: "repeat")
                    .foregroundColor(habit.streak > 0 ? .blue : .gray)
            } else {
                Image(systemName: "calendar")
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                if let time = item.scheduledTime {
                    Text("\(time, style: .time)")
                        .font(.subheadline)
                }
            }
            Spacer()
        }
    }
}

struct AddNewItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var selectedItemType = 0 // 0 for Task, 1 for Habit, 2 for FixedRoutine
    @State private var title = ""
    @State private var description: String?
    @State private var scheduledTime = Date()
    @State private var duration: TimeInterval?
    @State private var priority = 2
    @State private var dueDate: Date?
    @State private var reminder: Date?
    @State private var tags: [String] = []
    @State private var project: String?
    @State private var frequency: Habit.HabitFrequency = .daily
    @State private var specificDays: [Int] = []
    @State private var navigateToFixedRoutine = false // State to control NavigationLink

    var body: some View {
        NavigationView {
            Form {
                Picker("Item Type", selection: $selectedItemType) {
                    Text("Task").tag(0)
                    Text("Habit").tag(1)
                    Text("Fixed Routine").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())

                TextField("Title", text: $title)

                if selectedItemType != 2 { // Not FixedRoutine
                    TextField("Description (Optional)", text: $description)
                }

                DatePicker("Time", selection: $scheduledTime, displayedComponents: [.hourAndMinute])

                if selectedItemType != 2 { // Not FixedRoutine
                    Stepper("Duration (minutes): \(Int(duration ?? 0))", value: $duration, in: 0...600, step: 5)
                }

                Stepper("Priority: \(priority)", value: $priority, in: 1...3)

                if selectedItemType == 0 { // Task
                    DatePicker("Due Date (Optional)", selection: $dueDate, displayedComponents: [.date])
                }

                DatePicker("Reminder (Optional)", selection: $reminder, displayedComponents: [.date, .hourAndMinute])

                TextField("Tags (comma-separated)", text: .constant(tags.joined(separator: ",")))
                    .onAppear {
                        // Load existing tags from the item (if editing)
                    }
                    .onDisappear {
                        tags = $0.wrappedValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }

                TextField("Project (Optional)", text: $project)

                if selectedItemType == 1 { // Habit
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
                }

                Button(action: {
                    saveItem()
                }) {
                    Text("Save")
                }

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                }

                // NavigationLink for FixedRoutine creation
                NavigationLink(destination: CreateFixedRoutineView(isPresented: $isPresented), isActive: $navigateToFixedRoutine) {
                    EmptyView()
                }
            }
            .navigationTitle(selectedItemType == 0 ? "Add Task" : (selectedItemType == 1 ? "Add Habit" : "Add Fixed Routine"))
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.error.localizedDescription), dismissButton: .default(Text("OK")))
            }
        }
    }

    func saveItem() {
        switch selectedItemType {
        case 0: // Task
            let newTask = Task(title: title, description: description, isScheduled: true, scheduledDate: selectedDate, scheduledTime: scheduledTime, duration: duration, priority: priority, dueDate: dueDate, reminder: reminder, tags: tags, project: project)
            do {
                try routineManager.scheduleItem(item: newTask, date: selectedDate, time: scheduledTime)
                presentationMode.wrappedValue.dismiss()
            } catch RoutineManager.RoutineManagerError.schedulingConflict(let conflictingItem) {
                routineManager.dataManager.error = IdentifiableError(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Scheduling conflict with \(conflictingItem.title)."]))
            } catch {
                routineManager.dataManager.error = IdentifiableError(error: error)
            }
        case 1: // Habit
            let newHabit = Habit(title: title, description: description, isScheduled: true, scheduledDate: selectedDate, scheduledTime: scheduledTime, duration: duration, priority: priority, reminder: reminder, tags: tags, project: project, frequency: frequency)
            newHabit.specificDays = specificDays
            do {
                try routineManager.scheduleItem(item: newHabit, date: selectedDate, time: scheduledTime)
                presentationMode.wrappedValue.dismiss()
            } catch RoutineManager.RoutineManagerError.schedulingConflict(let conflictingItem) {
                routineManager.dataManager.error = IdentifiableError(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Scheduling conflict with \(conflictingItem.title)."]))
            } catch {
                routineManager.dataManager.error = IdentifiableError(error: error)
            }
        case 2: // FixedRoutine
            navigateToFixedRoutine = true // Activate the NavigationLink
        default:
            break
        }
    }
}

struct MultiSelectPicker: View {
    @Binding var selectedItems: [Int]
    let allItems: [Int]
    let itemFormatter: (Int) -> String

    var body: some View {
        ForEach(allItems, id: \.self) { item in
            Button(action: {
                if selectedItems.contains(item) {
                    selectedItems.removeAll(where: { $0 == item })
                } else {
                    selectedItems.append(item)
                }
            }) {
                HStack {
                    Text(itemFormatter(item))
                    Spacer()
                    if selectedItems.contains(item) {
                        Image(systemName: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "circle")
                    }
                }
            }
        }
    }
}

struct RoutineItemDetailView: View {
    var item: Scheduleable

    var body: some View {
        VStack {
            Text(item.title)
                .font(.largeTitle)
                .padding()

            if let task = item as? Task {
                TaskDetailView(task: task)
            } else if let habit = item as? Habit {
                HabitDetailView(habit: habit)
            } else if let event = item as? GTLRCalendar_Event {
                EventDetailView(event: event)
            } else {
                // Default view for unknown Scheduleable types
                Text("Unknown Item Type")
            }
        }
    }
}

struct RoutineView_Previews: PreviewProvider {
    static var previews: some View {
        RoutineView()
    }
}
