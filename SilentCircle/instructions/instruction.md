# Project Overview
Silent Circle is an iOS app built with Swift and SwiftUI. The app automatically silences the phone when the user enters a predefined geofenced area. It focuses on intuitive usability, efficient performance, and a clean, maintainable codebase.

# Scope and Requirements
## Core Functionality
- **Geofencing:**
  - Users can add, update, and delete geofences with details like name, location (latitude/longitude), and radius.
  - App monitors geofence entry/exit and toggles phone's silent mode accordingly.
  - Debug logs must track geofence events for clarity and troubleshooting.

- **User Interface:**
  - Display a list of geofences with their name and active/inactive status.
  - Provide an "Add Geofence" view to create new geofences with a map interface for location selection.
  - Use modern, accessible SwiftUI patterns for all screens.

- **State Management:**
  - Use `@State`, `@Binding`, `@ObservedObject`, or `@EnvironmentObject` where appropriate for managing view and shared state.
  - Avoid unnecessary re-renders and structure state updates to be efficient and clear.

- **Notifications:**
  - Trigger local notifications when the user enters or exits a geofenced area.
  - Provide clear options for managing notification permissions.

## Advanced Features
- **Persistence:**
  - Use Core Data to store geofence data persistently.
  - Ensure CRUD (Create, Read, Update, Delete) operations are implemented cleanly with proper error handling.
  - Use efficient fetch requests and pagination (if needed).

- **Performance Optimization:**
  - Use `LazyVStack` or `LazyHStack` for any list displaying large datasets.
  - Avoid deep view hierarchies by creating reusable, modular SwiftUI components.
  - Minimize `.id()` modifier usage unless necessary.

- **Lifecycle Management:**
  - Use `@StateObject` to manage `ObservableObject` lifecycles within views.
  - Avoid heavy operations in `onAppear`; delegate to background threads or use `Task` for async operations with proper cancellation.

## Code Quality
- **Debug Logs & Comments:**
  - Add meaningful debug logs to track state changes, geofence events, and user interactions.
  - Use comments to explain non-obvious sections of code for maintainability.

- **Modular Architecture:**
  - Use an MVVM (Model-View-ViewModel) architecture for clarity and separation of concerns.
  - Place code logically in directories (`Views`, `ViewModels`, `Managers`, `Models`, `Extensions`, etc.).

## Testing
- Write unit tests for Core Data operations, state management, and geofencing logic.
- Test UI flows for adding, updating, and deleting geofences.

# Swift-Specific Rules
- **State Management**:
  - Prefer `@State` for local view state and `@ObservedObject` or `@EnvironmentObject` for shared state.
  - Use computed properties for derived state to optimize performance and minimize unnecessary updates.

- **Performance Optimization**:
  - Use `LazyVStack` or `LazyHStack` for lists with large datasets.
  - Avoid excessive re-renders caused by unnecessary state changes or `.id()` usage.
  - Cache expensive computations in `@State` or `@StateObject`.

- **SwiftUI Lifecycle**:
  - Use `onAppear` and `onDisappear` sparingly and only for essential actions (e.g., async data fetching, animations).
  - Use `Task` for async operations to ensure clean cancellation behavior.

# Project Structure
.
├── Assets.xcassets
│   ├── AccentColor.colorset
│   ├── AppIcon.appiconset
├── ContentView.swift
├── Extensions
├── Managers
│   ├── GeofenceFetchManager.swift
│   ├── LocationManager.swift
│   ├── NotificationManager.swift
├── Models
│   ├── CoordinateWrapper.swift
├── Persistence.swift
├── Views
│   ├── AddGeofenceView.swift
│   ├── GeofenceListView.swift
│   ├── Components
│   │   ├── StatusGroup.swift
│   │   └── StatusIndicator.swift
├── ViewModels
│   ├── AddGeofenceViewModel.swift
│   ├── GeofenceListViewModel.swift
│   ├── UpdateGeofenceViewModel.swift
│   ├── LocationSearchViewModel.swift

# Tech Stack
- Language: Swift
- Framework: SwiftUI
- Persistence: Core Data
- State Management: SwiftUI (`@State`, `@Binding`, `@ObservedObject`, `@EnvironmentObject`)
- Geofencing: Core Location
- Notifications: UserNotifications Framework

# Output Expectations
- Code must adhere to Swift and SwiftUI best practices.
- Include debug logs and meaningful comments for easier debugging and maintenance.
- Test code thoroughly and provide clear error-handling mechanisms.
