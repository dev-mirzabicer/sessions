import SwiftUI

struct TasksView: View {
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var isAddingTask = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        KanbanColumn(title: "Not Started", tasks: routineManager.tasks.filter { $0.status == .notStarted }, color: .gray)
                        KanbanColumn(title: "In Progress", tasks: routineManager.tasks.filter { $0.status == .inProgress }, color: .blue)
                        KanbanColumn(title: "Done", tasks: routineManager.tasks.filter { $0.status == .done }, color: .green)
                    }
                    .padding()
                }

                Button(action: {
                    isAddingTask = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                .padding()
            }
            .navigationTitle("Tasks")
            .sheet(isPresented: $isAddingTask) {
                AddTaskView(isPresented: $isAddingTask, tasks: $routineManager.tasks)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                routineManager.loadTasks()
            }
        }
    }
}

struct KanbanColumn: View {
    var title: String
    @ObservedObject var tasks: [Task] // Use @ObservedObject for dynamic updates
    var color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .padding(.bottom)

            ForEach(tasks) { task in
                TaskCardView(task: task)
                    .onDrag {
                        return NSItemProvider(object: task.id as NSItemProviderWriting)
                    }
                    .onDrop(of: [.text], delegate: TaskDropDelegate(tasks: $tasks, columnTitle: title))
            }
        }
        .padding()
        .frame(width: 250)
        .background(color)
        .cornerRadius(10)
    }
}

struct TaskCardView: View {
    var task: Task

    var body: some View {
        VStack(alignment: .leading) {
            Text(task.title)
                .font(.headline)
            if let description = task.description {
                Text(description)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(5)
        .shadow(radius: 1)
    }
}

struct TaskDropDelegate: DropDelegate {
    @Binding var tasks: [Task]
    let columnTitle: String

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else { return false }

        item.loadObject(ofClass: UUID.self) { uuid, _ in
            if let taskID = uuid, let sourceIndex = tasks.firstIndex(where: { $0.id == taskID }) {
                let draggedTask = tasks.remove(at: sourceIndex)

                switch columnTitle {
                case "Not Started":
                    draggedTask.status = .notStarted
                case "In Progress":
                    draggedTask.status = .inProgress
                case "Done":
                    draggedTask.status = .done
                default:
                    break
                }

                tasks.append(draggedTask)
            }
        }

        return true
    }
}

struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @Binding var tasks: [Task]
    @State private var taskTitle = ""
    @State private var taskDescription: String?
    @State private var taskDuration: TimeInterval = 0
    @ObservedObject var routineManager = RoutineManager.shared

    var body: some View {
        NavigationView {
            Form {
                TextField("Title", text: $taskTitle)
                TextField("Description (Optional)", text: $taskDescription)
                Stepper("Duration (minutes): \(Int(taskDuration))", value: $taskDuration, in: 0...600, step: 5)

                Button(action: {
                    addTask()
                }) {
                    Text("Add Task")
                }
            }
            .navigationTitle("Add Task")
        }
    }

    func addTask() {
        guard !taskTitle.isEmpty else {
            return
        }

        let newTask = Task(title: taskTitle, description: taskDescription, duration: taskDuration)
        tasks.append(newTask)
        do {
            try routineManager.dataManager.saveTask(task: newTask)
        } catch {
            print("Error saving task: \(error.localizedDescription)")
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
    }
}
