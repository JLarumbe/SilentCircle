# Silent Circle 

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS_16+-blue.svg)](https://developer.apple.com/ios/)

A privacy-focused iOS app that automatically silences your phone when entering designated areas. Built with modern SwiftUI and Core Location.

## Screenshots 

<div style="display: flex; flex-wrap: wrap; gap: 16px; justify-content: center">

### Home View
<img src="https://github.com/user-attachments/assets/b26654dd-febc-4c36-8a66-6d071bc3d9b0" width="300" style="border-radius: 12px" title="Home Screen - List View">

### Add Geofence
<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px">
  <img src="https://github.com/user-attachments/assets/538fbc2a-aec1-4396-b916-3e23afd6aeaa" width="140" title="1. Map Selection">
  <img src="https://github.com/user-attachments/assets/b1423e63-2350-4b68-ad7b-9483316ede2d" width="140" title="2. Radius Adjustment">
  <img src="https://github.com/user-attachments/assets/a1969905-015e-41f6-aa73-dc824cf08d62" width="140" title="3. Name Entry">
  <img src="https://github.com/user-attachments/assets/ec792719-daa0-4f98-92aa-e018b4cbf343" width="140" title="4. Confirmation">
</div>

### Edit Geofence
<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px">
  <img src="https://github.com/user-attachments/assets/0836a2c4-d3ab-4fcb-9531-6abfad7c4bb3" width="140" title="1. Edit Overview">
  <img src="https://github.com/user-attachments/assets/60d1a64f-c5d9-4c0b-bb6f-db222cc98f7d" width="140" title="2. Location Update">
  <img src="https://github.com/user-attachments/assets/921846ce-cbb4-43ce-b1d8-6009f04cba04" width="140" title="3. Radius Update">
  <img src="https://github.com/user-attachments/assets/355d8b6e-9813-4eec-9e73-e5c10d8e91f3" width="140" title="4. Save Changes">
</div>

### Delete Flow
<div style="display: flex; gap: 8px">
  <img src="https://github.com/user-attachments/assets/a720cd08-5acd-4b6b-a8d3-eb48ce6c8ff4" width="200" title="1. Delete Confirmation">
  <img src="https://github.com/user-attachments/assets/f1df2de1-a736-401d-9997-1e061e927eba" width="200" title="2. Success Toast">
</div>

### Settings
<img src="https://github.com/user-attachments/assets/338467d8-ebf9-4ab8-8d9b-b2ffea46491b" width="300" style="margin-top: 12px" title="Settings Screen">

</div>

## Features 
- Create geofences with custom names/radii
- Automatic silent mode activation
- Real-time location tracking
- Entry/exit notifications
- Modular SwiftUI architecture
- Core Data persistence

## Tech Stack 
- **UI**: SwiftUI, MapKit
- **Data**: Core Data, @AppStorage
- **Location**: Core Location, Geofencing
- **Architecture**: MVVM, Combine
- **Testing**: XCTest, Core Data in-memory store

## Code Quality 
- MVVM architecture
- Combine for reactive programming
- Core Data with background contexts
- Extensive debug logging
- Full accessibility support
- Swift Concurrency adoption

## Why This Project? 
Demonstrates mastery of:
- Modern SwiftUI development
- Core Location geofencing
- Reactive programming patterns
- Performance optimization
- App Store submission best practices
