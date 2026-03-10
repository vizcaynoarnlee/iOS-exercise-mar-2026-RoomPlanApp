# RoomPlan - 3D Room Scanning with Photo Capture

iOS application combining Apple's RoomPlan SDK for professional 3D room scanning with ARKit-based spatial photo capture. Built with SwiftUI and Swift 6, following MVVM architecture with full dependency injection.

## Overview

RoomPlanApp enables users to scan rooms in 3D using LiDAR technology, capture photos during the scanning process, and view the results in an interactive 3D viewer. All data is stored locally with no backend required.

**Key Capabilities:**
- 3D room geometry capture using RoomPlan SDK
- Real-time spatial photo capture with quaternion-based pose tracking
- Photo-to-wall mapping in 3D viewer
- USDZ model export
- Persistent local storage with JSON metadata

## Features

- 🏠 **3D Room Scanning** - LiDAR-powered room geometry capture with RoomPlan SDK
- 📸 **Spatial Photo Capture** - ARKit-based camera pose tracking with quaternion orientation
- 🎨 **Interactive 3D Viewer** - SceneKit-based viewer with photos mapped to walls
- 💾 **Local Persistence** - File-based storage with USDZ models and photo metadata
- 🔐 **Permission Management** - Camera and ARKit authorization handling
- 🧪 **Protocol-Based Architecture** - Full dependency injection for testability

## Requirements

### Hardware
- LiDAR-equipped device required for room scanning:
  - iPhone 12 Pro or later
  - iPad Pro (2020 or later)
- ARKit support required

### Software
- iOS 18.0+
- Xcode 16.0+
- Swift 6

## Quick Start

### Open in Xcode
```bash
cd RoomPlanApp
open RoomPlanApp.xcodeproj
```

### Build from Command Line
```bash
# iOS Simulator
xcodebuild -project RoomPlanApp/RoomPlanApp.xcodeproj \
  -scheme RoomPlanApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Physical Device (requires LiDAR)
xcodebuild -project RoomPlanApp/RoomPlanApp.xcodeproj \
  -scheme RoomPlanApp \
  -sdk iphoneos \
  build
```

### Run Tests
```bash
xcodebuild test -project RoomPlanApp/RoomPlanApp.xcodeproj \
  -scheme RoomPlanApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Project Structure

```
RoomPlanApp/
├── App/                          # Application entry point
├── Models/                       # Data models (SpatialPose, ScanPhoto, RoomScan)
├── Services/                     # Shared services (Persistence, Permissions)
│   └── Protocols/               # Protocol interfaces for DI
├── Modules/                      # Feature modules (Dashboard, RoomCapture, Viewer)
│   ├── Dashboard/               # Scan list and management
│   ├── RoomCapture/             # Room scanning with RoomPlan SDK
│   └── Viewer/                  # 3D SceneKit viewer
└── Resources/                    # Assets and resources
```

## Technology Stack

- **SwiftUI** - Declarative UI framework
- **RoomPlan SDK** - Apple's 3D room scanning framework
- **ARKit** - Camera pose tracking and spatial data
- **SceneKit** - 3D rendering and visualization
- **Swift 6** - With strict concurrency checking
- **@Observable** - Swift observation framework
- **Codable** - JSON serialization

## Documentation

### Core Documentation

- **[Architecture Guide](RoomPlanApp/Documentation/ARCHITECTURE.md)** - MVVM pattern, data models, dependency injection, and architectural decisions
- **[Implementation Details](RoomPlanApp/Documentation/IMPLEMENTATION.md)** - Complete implementation guide including data flow, persistence layer, concurrency model, and code examples
- **[Module Documentation](RoomPlanApp/Documentation/MODULES.md)** - Individual module documentation for Dashboard, RoomCapture, and Viewer

### Additional Resources

- **[CLAUDE.md](CLAUDE.md)** - Claude Code integration and project instructions
- **Module-Specific Docs:**
  - [Dashboard Implementation](RoomPlanApp/RoomPlanApp/Modules/Dashboard/Documentation/DASHBOARD_IMPLEMENTATION.md)
  - [RoomCapture Implementation](RoomPlanApp/RoomPlanApp/Modules/RoomCapture/Documentation/ROOMCAPTURE_IMPLEMENTATION.md)
  - [Viewer Implementation](RoomPlanApp/RoomPlanApp/Modules/Viewer/Documentation/VIEWER_IMPLEMENTATION.md)

## Architecture Highlights

**MVVM + Services Pattern**
- ViewModels handle business logic and UI state (@MainActor isolated)
- Services provide shared functionality (thread-agnostic)
- Protocol-based dependency injection for full testability

**Data Models**
- `SpatialPose` - 3D position (SIMD3) + quaternion orientation (simd_quatf)
- `ScanPhoto` - Photo with spatial metadata and capture date
- `RoomScan` - Container with USDZ model + photos (@Observable class)

**Concurrency**
- Swift 6 strict concurrency enabled
- @MainActor isolation for UI components
- Sendable conformance for data models
- Background queues for USDZ export and image processing

## Development

### Code Quality Standards
- Protocol-oriented design for testability
- SOLID principles throughout
- Swift 6 concurrency safety
- Comprehensive documentation
- Debug logging for all major operations

### Testing
```bash
# Run all tests
xcodebuild test -project RoomPlanApp/RoomPlanApp.xcodeproj \
  -scheme RoomPlanApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run specific test class
xcodebuild test -project RoomPlanApp/RoomPlanApp.xcodeproj \
  -scheme RoomPlanApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:RoomPlanAppTests/RoomPlanAppTests
```

## File Storage Structure

```
Documents/
└── RoomScans/
    ├── {scan-uuid-1}/
    │   ├── scan.json              # Metadata with photo poses
    │   ├── room.usdz              # 3D model
    │   └── photos/
    │       ├── {photo-uuid-1}.jpg
    │       ├── {photo-uuid-2}.jpg
    │       └── ...
    └── {scan-uuid-2}/
        └── ...
```

## License

Internal use only - Arnlee Vizcayno
