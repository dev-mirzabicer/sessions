import SwiftUI

struct FixedRoutinesView: View {
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var isAddingRoutine = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(routineManager.fixedRoutines) { routine in
                        NavigationLink(destination: FixedRoutineDetailView(routine: routine)) {
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
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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
                try routineManager.dataManager.deleteScheduleable(scheduleable: routineToDelete)
            } catch {
                alertMessage = "Error deleting fixed routine: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

struct FixedRoutineRowView: View {
    var routine: FixedRoutine

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(routine.title)
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
    @ObservedObject var routine: FixedRoutine
    @State private var isEditing = false
    @State private var isRunning = false
    @State private var progress: Double = 0.0
    @State private var remainingTime: TimeInterval = 0
    private var timer: Timer?

    var body: some View {
        VStack {
            List {
                Section(header: Text("Details")) {
                    DetailRow(label: "Description", value: routine.description ?? "-")
                    DetailRow(label: "Start Time", value: routine.startTime != nil ? "\(routine.startTime!, style: .time)" : "-")
                    DetailRow(label: "Flexibility", value: routine.flexibility != nil ? "\(Int(routine.flexibility! / 60)) minutes" : "-")
                    DetailRow(label: "Recurrence", value: routine.recurrence.rawValue)
                }

                Section(header: Text("Tasks")) {
                    ForEach(routine.tasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            Text(task.title)
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
        .navigationTitle(routine.title)
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
            EditFixedRoutineView(routine: routine, isPresented: $isEditing)
        }
        .onAppear {
            routine.loadRoutineProgress()
            if routine.getCurrentTask() != nil {
                isRunning = true
                startTimer()
            }
        }
        .onDisappear {
            stopTimer() // Stop the timer when the view disappears
        }
    }

    private func startRoutine() {
        routine.startRoutine()
        isRunning = true
        startTimer()
    }

    private func stopRoutine() {
        routine.pauseRoutine()
        isRunning = false
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let currentTask = routine.getCurrentTask() {
                remainingTime = (currentTask.duration ?? 0) - routine.elapsedTime
                progress = routine.getProgress()
            } else {
                stopRoutine()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
    @State private var tasks: [Task] = []
    @State private var isAddingTask = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

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
                    ForEach(tasks) { task in
                        Text(task.title)
                    }
                    .onDelete(perform: deleteTask)

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
                AddTaskView(isPresented: $isAddingTask, tasks: $tasks)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    func deleteTask(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }

    func saveFixedRoutine() {
        guard !routineTitle.isEmpty else {
            alertMessage = "Please enter a title for the routine."
            showingAlert = true
            return
        }

        guard !tasks.isEmpty else {
            alertMessage = "Please add at least one task to the routine."
            showingAlert = true
            return
        }

        let newFixedRoutine = FixedRoutine(title: routineTitle,
                                          description: routineDescription,
                                          tasks: tasks,
                                          recurrence: recurrence,
                                          startTime: routineStartTime,
                                          flexibility: routineFlexibility)

        do {
            try routineManager.dataManager.saveFixedRoutine(fixedRoutine: newFixedRoutine)
            routineManager.fixedRoutines.append(newFixedRoutine)
            presentationMode.wrappedValue.dismiss()
            isPresented = false
        } catch {
            alertMessage = "Error saving fixed routine: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct EditFixedRoutineView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var routine: FixedRoutine
    @Binding var isPresented: Bool
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Routine Details")) {
                    TextField("Title", text: $routine.title)
                    TextField("Description (Optional)", text: $routine.description)
                    DatePicker("Start Time", selection: $routine.startTime ?? Date(), displayedComponents: [.hourAndMinute])
                    Stepper("Flexibility (minutes): \(Int(routine.flexibility ?? 0) / 60)", value: $routine.flexibility, in: 0...600, step: 5)
                    Picker("Recurrence", selection: $routine.recurrence) {
                        ForEach(FixedRoutine.Recurrence.allCases, id: \.self) { recurrence in
                            Text(recurrence.rawValue).tag(recurrence)
                        }
                    }
                }

                Section(header: Text("Tasks")) {
                    ForEach(routine.tasks) { task in
                        Text(task.title)
                    }
                    .onDelete(perform: deleteTask)

                    NavigationLink(destination: AddTaskView(isPresented: .constant(false), tasks: $routine.tasks)) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
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
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    func deleteTask(at offsets: IndexSet) {
        routine.tasks.remove(atOffsets: offsets)
    }

    func saveFixedRoutine() {
        guard !routine.title.isEmpty else {
            alertMessage = "Please enter a title for the routine."
            showingAlert = true
            return
        }

        guard !routine.tasks.isEmpty else {
            alertMessage = "Please add at least one task to the routine."
            showingAlert = true
            return
        }

        do {
            try routineManager.dataManager.saveFixedRoutine(fixedRoutine: routine)
            if let index = routineManager.fixedRoutines.firstIndex(where: { $0.id == routine.id }) {
                routineManager.fixedRoutines[index] = routine
            }
            presentationMode.wrappedValue.dismiss()
        } catch {
            alertMessage = "Error saving fixed routine: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct FixedRoutinesView_Previews: PreviewProvider {
    static var previews: some View {
        FixedRoutinesView()
    }
}
