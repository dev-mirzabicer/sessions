import SwiftUI

struct FixedRoutinesView: View {
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var isAddingRoutine = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach($routineManager.fixedRoutines) { $routine in
                        NavigationLink(destination: FixedRoutineDetailView(routine: $routine)) {
                            FixedRoutineRowView(routine: routine)
                        }
                    }
                    .onDelete(perform: deleteFixedRoutine)
                }
                .listStyle(PlainListStyle())

                Button(action: {
                    isAddingRoutine = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                .padding()
            }
            .navigationTitle("Fixed Routines")
            .sheet(isPresented: $isAddingRoutine) {
                CreateFixedRoutineView(isPresented: $isAddingRoutine)
            }
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                routineManager.loadFixedRoutines()
            }
        }
    }

    func deleteFixedRoutine(at offsets: IndexSet) {
        if let index = offsets.first {
            let routineToDelete = routineManager.fixedRoutines[index]
            routineManager.fixedRoutines.remove(at: index)
            do {
                try routineManager.dataManager.deleteFixedRoutine(routineToDelete)
            } catch {
                routineManager.dataManager.error = error
            }
        }
    }
}

struct FixedRoutineRowView: View {
    @ObservedObject var routine: FixedRoutineEntity

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(routine.title ?? "")
                    .font(.headline)
                if let startTime = routine.startTime {
                    Text("\(startTime, style: .time)")
                        .font(.subheadline)
                }
            }
            Spacer()
        }
    }
}

struct FixedRoutineDetailView: View {
    @Binding var routine: FixedRoutineEntity
    @State private var isEditing = false
    @State private var isRunning = false
    @State private var progress: Double = 0.0
    @State private var remainingTime: TimeInterval = 0
    @State private var timer: Timer? // Use @State for the timer

    var body: some View {
        VStack {
            List {
                Section(header: Text("Details")) {
                    DetailRow(label: "Description", value: routine.routineDescription ?? "-")
                    DetailRow(label: "Start Time", value: routine.startTime != nil ? "\(routine.startTime!, style: .time)" : "-")
                    DetailRow(label: "Flexibility", value: routine.flexibility != nil ? "\(Int(routine.flexibility!.doubleValue / 60)) minutes" : "-")
                    DetailRow(label: "Recurrence", value: routine.recurrence ?? "-")
                }

                Section(header: Text("Tasks")) {
                    ForEach(routine.tasks?.allObjects as? [TaskEntity] ?? []) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            Text(task.title ?? "")
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())

            if isRunning {
                ProgressView(value: progress, total: 1)
                    .accentColor(.blue)
                    .padding()
                    .scaleEffect(x: 1, y: 4, anchor: .center)

                Text("Remaining Time: \(formattedRemainingTime)")
                    .font(.headline)
                    .padding()

                Button(action: {
                    stopRoutine()
                }) {
                    Text("Stop Routine")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding()
            } else {
                Button(action: {
                    startRoutine()
                }) {
                    Text("Start Routine")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .navigationTitle(routine.title ?? "")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditFixedRoutineView(routine: $routine, isPresented: $isEditing)
        }
        .onAppear {
            loadRoutineProgress()
            if routine.tasks?.count ?? 0 > 0 {
                isRunning = true
                startTimer()
            }
        }
        .onDisappear {
            stopTimer() // Invalidate the timer when the view disappears
        }
    }

    private func startRoutine() {
        // Convert the FixedRoutineEntity to a FixedRoutine for timer management
        var fixedRoutine = routine.toFixedRoutine()
        fixedRoutine.startRoutine()

        // Update the isRunning state and start the timer
        isRunning = true
        startTimer()
    }

    private func stopRoutine() {
        // Convert the FixedRoutineEntity to a FixedRoutine for timer management
        var fixedRoutine = routine.toFixedRoutine()
        fixedRoutine.pauseRoutine()

        // Update the isRunning state and stop the timer
        isRunning = false
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // Convert the FixedRoutineEntity to a FixedRoutine to get progress and remaining time
            let fixedRoutine = routine.toFixedRoutine()
            if let currentTask = fixedRoutine.getCurrentTask() {
                remainingTime = (currentTask.duration ?? 0) - fixedRoutine.elapsedTime
                progress = fixedRoutine.getProgress()
            } else {
                stopRoutine()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func loadRoutineProgress() {
        // Convert the FixedRoutineEntity to a FixedRoutine to load progress
        var fixedRoutine = routine.toFixedRoutine()
        fixedRoutine.loadRoutineProgress()

        // Update the progress and remaining time based on the loaded progress
        progress = fixedRoutine.getProgress()
        if let currentTask = fixedRoutine.getCurrentTask() {
            remainingTime = (currentTask.duration ?? 0) - fixedRoutine.elapsedTime
        }
    }

    private var formattedRemainingTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CreateFixedRoutineView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var routineTitle = ""
    @State private var routineDescription: String?
    @State private var routineStartTime = Date()
    @State private var routineFlexibility: TimeInterval?
    @State private var recurrence: FixedRoutine.Recurrence = .daily
    @State private var selectedTaskIDs: [UUID] = []
    @State private var isAddingTask = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Routine Details")) {
                    TextField("Title", text: $routineTitle)
                    TextField("Description (Optional)", text: $routineDescription)
                    DatePicker("Start Time", selection: $routineStartTime, displayedComponents: [.hourAndMinute])
                    Stepper("Flexibility (minutes): \(Int(routineFlexibility ?? 0))", value: $routineFlexibility, in: 0...600, step: 5)
                    Picker("Recurrence", selection: $recurrence) {
                        ForEach(FixedRoutine.Recurrence.allCases, id: \.self) { recurrence in
                            Text(recurrence.rawValue).tag(recurrence)
                        }
                    }
                }

                Section(header: Text("Tasks")) {
                    ForEach(routineManager.tasks) { task in
                        Button(action: {
                            if selectedTaskIDs.contains(task.id!) {
                                selectedTaskIDs.removeAll(where: { $0 == task.id! })
                            } else {
                                selectedTaskIDs.append(task.id!)
                            }
                        }) {
                            HStack {
                                Text(task.title ?? "")
                                Spacer()
                                if selectedTaskIDs.contains(task.id!) {
                                    Image(systemName: "checkmark.circle.fill")
                                } else {
                                    Image(systemName: "circle")
                                }
                            }
                        }
                    }

                    Button(action: {
                        isAddingTask = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
                        }
                    }
                }

                Button(action: {
                    saveFixedRoutine()
                }) {
                    Text("Save Routine")
                }
            }
            .navigationTitle("Create Fixed Routine")
            .sheet(isPresented: $isAddingTask) {
                AddTaskView(isPresented: $isAddingTask)
            }
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                routineManager.loadTasks()
            }
        }
    }

    func saveFixedRoutine() {
        guard !routineTitle.isEmpty else {
            routineManager.dataManager.error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Please enter a title for the routine."])
            return
        }

        let selectedTasks = routineManager.tasks.filter { selectedTaskIDs.contains($0.id!) }

        do {
            try routineManager.dataManager.saveFixedRoutine(title: routineTitle, description: routineDescription, startTime: routineStartTime, flexibility: routineFlexibility, recurrence: recurrence, tasks: selectedTasks)
            routineManager.loadFixedRoutines()
            presentationMode.wrappedValue.dismiss()
            isPresented = false
        } catch {
            routineManager.dataManager.error = error
        }
    }
}

struct EditFixedRoutineView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var routine: FixedRoutineEntity
    @Binding var isPresented: Bool
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var selectedTaskIDs: [UUID] = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Routine Details")) {
                    TextField("Title", text: $routine.title)
                    TextField("Description (Optional)", text: $routine.routineDescription)
                    DatePicker("Start Time", selection: $routine.startTime ?? Date(), displayedComponents: [.hourAndMinute])
                    Stepper("Flexibility (minutes): \(Int(routine.flexibility?.doubleValue ?? 0) / 60)", value: $routine.flexibility, in: 0...600, step: 5)
                    Picker("Recurrence", selection: $routine.recurrence) {
                        ForEach(FixedRoutine.Recurrence.allCases, id: \.self) { recurrence in
                            Text(recurrence.rawValue).tag(recurrence)
                        }
                    }
                }

                Section(header: Text("Tasks")) {
                    ForEach(routineManager.tasks) { task in
                        Button(action: {
                            if selectedTaskIDs.contains(task.id!) {
                                selectedTaskIDs.removeAll(where: { $0 == task.id! })
                            } else {
                                selectedTaskIDs.append(task.id!)
                            }
                        }) {
                            HStack {
                                Text(task.title ?? "")
                                Spacer()
                                if selectedTaskIDs.contains(task.id!) {
                                    Image(systemName: "checkmark.circle.fill")
                                } else {
                                    Image(systemName: "circle")
                                }
                            }
                        }
                    }
                }

                Button(action: {
                    saveFixedRoutine()
                }) {
                    Text("Save Changes")
                }
            }
            .navigationTitle("Edit Fixed Routine")
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                routineManager.loadTasks()
                selectedTaskIDs = routine.tasks?.allObjects.compactMap { ($0 as? TaskEntity)?.id } ?? []
            }
        }
    }

    func saveFixedRoutine() {
        guard let routineTitle = routine.title, !routineTitle.isEmpty else {
            routineManager.dataManager.error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Please enter a title for the routine."])
            return
        }

        let selectedTasks = routineManager.tasks.filter { selectedTaskIDs.contains($0.id!) }

        do {
            try routineManager.dataManager.updateFixedRoutine(routine, title: routineTitle, description: routine.routineDescription, startTime: routine.startTime, flexibility: routine.flexibility?.doubleValue, recurrence: FixedRoutine.Recurrence(rawValue: routine.recurrence ?? "") ?? .daily, tasks: selectedTasks)
            presentationMode.wrappedValue.dismiss()
            isPresented = false
        } catch {
            routineManager.dataManager.error = error
        }
    }
}

struct FixedRoutinesView_Previews: PreviewProvider {
    static var previews: some View {
        FixedRoutinesView()
    }
}
