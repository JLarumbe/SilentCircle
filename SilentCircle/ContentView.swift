//
//  ContentView.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            GeofenceListView(viewContext: viewContext)
                .navigationTitle("Geofences")
        }
    }
}

// Preview configuration with sample Core Data
#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
