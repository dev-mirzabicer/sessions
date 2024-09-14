import SwiftUI

struct TasksView: View {
    @ObservedObject var routineManager = RoutineManager.shared
    @State private var isAddingTask = false

    var body: some View {
        NavigationView {
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        KanbanColumn(title: "Not Started", tasks: $routineManager.tasks, status: "Not Started", color: .gray)
                        KanbanColumn(title: "In Progress", tasks: $routineManager.tasks, status: "In Progress", color: .blue)
                        KanbanColumn(title: "Done", tasks: $routineManager.tasks, status: "Done", color: .green)
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
                AddTaskView(isPresented: $isAddingTask)
            }
            .alert(item: $routineManager.dataManager.error) { error in
                Alert(title: Text("Error"), message: Text(error.error.localizedDescription), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                routineManager.loadTasks()
            }
        }
    }
}

struct KanbanColumn: View {
    var title: String
    @Binding var tasks: [TaskEntity]
    var status: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .padding(.bottom)

            ForEach(tasks.indices, id: \.self) { index in
                if tasks[index].status == status {
                    TaskCardView(task: tasks[index])
                        .onDrag {
                            return NSItemProvider(object: tasks[index].id! as NSItemProviderWriting)
                        }
                        .onDrop(of: [.text], delegate: TaskDropDelegate(tasks: $tasks, columnTitle: title))
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(color)
        .cornerRadius(10)
    }
}

struct TaskCardView: View {
    @ObservedObject var task: TaskEntity

    var body: some View {
        VStack(alignment: .leading) {
            Text(task.title ?? "")
                .font(.headline)
            if let description = task.taskDescription {
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
    @Binding var tasks: [TaskEntity]
    let columnTitle: String

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else { return false }

        item.loadObject(ofClass: UUID.self) { uuid, _ in
            if let taskID = uuid, let sourceIndex = tasks.firstIndex(where: { $0.id == taskID }) {
                let draggedTask = tasks[sourceIndex]

                // Update the task's status based on the target column
                switch columnTitle {
                case "Not Started":
                    draggedTask.status = "Not Started"
                case "In Progress":
                    draggedTask.status = "In Progress"
                case "Done":
                    draggedTask.status = "Done"
                default:
                    break
                }

                // Move the task to the end of the target column
                tasks.remove(at: sourceIndex)
                tasks.append(draggedTask)
            }
        }

        return true
    }
}

struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
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

        do {
            try routineManager.dataManager.saveTask(title: taskTitle, description: taskDescription, isScheduled: false, scheduledDate: nil, scheduledTime: nil, duration: taskDuration, priority: 2, dueDate: nil, reminder: nil, tags: nil, project: nil, status: .notStarted)
            routineManager.loadTasks() // Refresh the tasks array
        } catch {
            routineManager.dataManager.error = IdentifiableError(error: error)
        }

        presentationMode.wrappedValue.dismiss()
    }
}

struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
    }
}
