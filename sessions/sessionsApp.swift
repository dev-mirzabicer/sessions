//
//  sessionsApp.swift
//  sessions
//
//  Created by Mirza Biçer on 9/13/24.
//

import SwiftUI

@main
struct sessionsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
