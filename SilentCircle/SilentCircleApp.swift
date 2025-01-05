//
//  SilentCircleApp.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import SwiftUI

@main
struct SilentCircleApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
