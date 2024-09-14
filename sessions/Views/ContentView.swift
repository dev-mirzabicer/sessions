import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RoutineView()
                .tabItem {
                    Label("Routine", systemImage: "calendar")
                }

            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "list.star")
                }

            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle")
                }

            FixedRoutinesView()
                .tabItem {
                    Label("Routines", systemImage: "repeat")
                }
        }
        .accentColor(.blue)
    }
}
