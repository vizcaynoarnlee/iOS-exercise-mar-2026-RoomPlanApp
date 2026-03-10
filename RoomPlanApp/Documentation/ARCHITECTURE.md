# Architecture Guide

## Overview

RoomPlanApp follows MVVM architecture with dependency injection, ensuring clean separation of concerns and full testability.

## Architecture Pattern

**MVVM (Model-View-ViewModel) + Services**

```
┌─────────────┐
│    Views    │ SwiftUI views (presentation only)
└──────┬──────┘
       │
┌──────▼──────────┐
│  ViewModels     │ Business logic + UI state
└──────┬──────────┘
       │
┌──────▼──────────┐
│   Services      │ Shared functionality (persistence, permissions)
└──────┬──────────┘
       │
┌──────▼──────────┐
│    Models       │ Data structures (Codable, Observable)
└─────────────────┘
```

## Core Data Models

### SpatialPose
Represents position and orientation in 3D space.

```swift
struct SpatialPose: Codable, Sendable {
    var position: SIMD3<Float>      // X, Y, Z in meters
    var orientation: simd_quatf      // Rotation (quaternion)
}
```

**Note:** Timestamp is stored at the ScanPhoto level (captureDate), not in SpatialPose, to avoid redundancy.

**Why Quaternions?**
- No gimbal lock
- Efficient interpolation
- Standard in AR/VR systems
- Matches ARKit's coordinate system

### ScanPhoto
Photo captured during room scanning with spatial metadata.

```swift
struct ScanPhoto: Codable, Identifiable {
    let id: UUID
    var imageURL: URL               // Path to JPEG file
    var cameraPose: SpatialPose     // Where photo was taken
    var captureDate: Date
    var targetSurfaceID: UUID?      // Optional wall mapping
}
```

### RoomScan
Completed room scan with 3D model and photos.

```swift
@Observable
final class RoomScan: Codable, Identifiable {
    let id: UUID
    var name: String
    var usdURL: URL                 // USDZ 3D model
    var captureDate: Date
    var photos: [ScanPhoto]
    var directory: URL
}
```

**Note:** Class (not struct) for `@Observable` SwiftUI reactivity. Thread-safe because all mutations occur on `@MainActor`.

## Service Layer

### PersistenceService
Handles all file I/O operations.

**Responsibilities:**
- Save/load room scans
- Manage USDZ files
- Photo compression and storage
- Directory management

**Protocol:** `PersistenceProtocol` (for dependency injection)

### PermissionsManager
Manages app permissions and device capabilities.

**Responsibilities:**
- Camera permission requests
- ARKit capability checks
- LiDAR sensor detection

**Protocol:** `PermissionsProtocol` (for dependency injection)

## Module Structure

### Dashboard Module
Lists all saved room scans.

- **DashboardView** - SwiftUI list view
- **DashboardViewModel** - Load/delete scan logic

### RoomCapture Module
Handles room scanning workflow.

- **RoomCaptureView** - AR camera view + controls
- **RoomCaptureViewModel** - Scan state management
- **RoomCaptureCoordinator** - RoomPlan delegate

### Viewer Module
Displays 3D model with photos.

- **RoomViewerView** - SceneKit scene
- **RoomViewerViewModel** - View state

## Dependency Injection

All ViewModels accept dependencies via initializers with default values:

```swift
init(
    persistenceService: any PersistenceProtocol = PersistenceService.shared,
    permissionsManager: any PermissionsProtocol = PermissionsManager.shared
) {
    self.persistenceService = persistenceService
    self.permissionsManager = permissionsManager
}
```

**Benefits:**
- Testable with mock implementations
- No singleton coupling
- Follows Dependency Inversion Principle

## File Storage Structure

```
Documents/RoomScans/
├── {scan-uuid}/
│   ├── scan.json           # Metadata
│   ├── room.usdz           # 3D model
│   └── photos/
│       ├── {photo-uuid}.jpg
│       └── {photo-uuid}.jpg
```

## Coordinate System

- **Reference:** ARKit right-handed coordinate system
- **+X:** Right
- **+Y:** Up
- **+Z:** Backward (toward user)
- **Units:** Meters

RoomPlan and ARKit share the same coordinate space, ensuring accurate photo positioning.

## Configuration

Centralized in `AppConfiguration.swift`:

```swift
enum AppConfiguration {
    enum Image {
        static let jpegCompressionQuality: CGFloat = 0.85
    }

    enum FileSystem {
        static let scansDirectoryName = "RoomScans"
        static let photosDirectoryName = "photos"
    }
}
```

## Design Decisions

### Why MVVM?
- Natural fit for SwiftUI
- Clear separation of concerns
- Easy to test business logic

### Why Dependency Injection?
- Unit testing with mocks
- Flexible architecture
- SOLID principles compliance

### Why File-Based Storage?
- No backend complexity
- Full offline support
- User owns their data

### Why SceneKit over RealityKit?
- Mature, stable framework
- Better documentation
- Sufficient for 3D model display

## Code Quality Standards

- **MVVM:** Strict layer separation
- **SOLID:** All principles followed
- **Clean Code:** No magic numbers, short methods
- **Thread Safety:** All UI updates on `@MainActor`
- **Error Handling:** Proper error types with localized messages
