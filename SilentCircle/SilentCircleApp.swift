//
//  SilentCircleApp.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import SwiftUI

@main
struct SilentCircleApp: App {
    // Create a persistent controller instance to manage Core Data
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the managed object context into the environment
                // This makes it available to all child views
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
