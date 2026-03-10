# RoomPlan - 3D Room Scanning with Photo Capture

iOS application combining Apple's RoomPlan SDK for professional 3D room scanning with ARKit-based spatial photo capture. Built with SwiftUI and Swift 6, following MVVM architecture with full dependency injection.

## Overview

RoomPlanApp enables users to scan rooms in 3D using LiDAR technology, capture photos during the scanning process, and view the results in an interactive 3D viewer with immersive 360° panorama support. All data is stored locally with no backend required.

**Key Capabilities:**
- 3D room geometry capture using RoomPlan SDK
- Real-time spatial photo capture with quaternion-based pose tracking
- 360° immersive panorama viewer with equirectangular stitching
- Interactive 3D model viewer with orbit controls
- USDZ model export
- Persistent local storage with JSON metadata

**Current Status (March 2026):**
- ✅ Core scanning and viewing functionality complete
- ✅ Photo-to-wall mapping fully implemented (ray-plane intersection)
- ✅ Panorama viewer refactored and optimized (4-file architecture)
- ✅ Seam softening implemented (no ghosting, soft transitions)
- 🚧 Unit testing in progress
- 🚧 Panorama top/bottom fill planned
- 📊 ~15,000 lines of Swift code with comprehensive documentation

## Features

### Implemented ✅

- 🏠 **3D Room Scanning** - LiDAR-powered room geometry capture with RoomPlan SDK
- 📸 **Spatial Photo Capture** - ARKit-based camera pose tracking with quaternion orientation
- 🎨 **Interactive 3D Viewer** - SceneKit-based viewer with orbit controls and photo markers
- 🌐 **360° Panorama Viewer** - Immersive equirectangular sphere with edge-softened stitching
- 💾 **Local Persistence** - File-based storage with USDZ models and photo metadata
- 🔐 **Permission Management** - Camera and ARKit authorization handling
- 🧪 **Protocol-Based Architecture** - Full dependency injection for testability
- 🎯 **Refactored Panorama** - Separated into focused modules (Configuration, Stitcher, Controller, View)

### In Progress 🚧

- 🧪 **Unit Testing** - Core services and viewmodels
- 📊 **Dashboard Management** - Delete, rename, search scans
- 🎨 **Panorama Quality** - Fill top/bottom black space, async stitching

### Planned 📅

- 🔄 **Async Panorama Stitching** - Background processing with progress indicator
- 🎨 **Advanced Stitching** - Multi-band blending for seamless panoramas
- 📤 **Export & Sharing** - AR Quick Look, OBJ export, photo archives
- 🌍 **Gyroscope Support** - Device motion for panorama navigation

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
│   │   ├── DashboardView.swift
│   │   ├── DashboardViewModel.swift
│   │   └── Documentation/
│   ├── RoomCapture/             # Room scanning with RoomPlan SDK
│   │   ├── RoomCaptureView.swift
│   │   ├── RoomCaptureViewModel.swift
│   │   ├── RoomCaptureCoordinator.swift
│   │   └── Documentation/
│   └── Viewer/                  # 3D SceneKit viewer
│       ├── RoomViewerView.swift
│       ├── RoomViewerViewModel.swift
│       ├── SpatialPanorama/    # 360° panorama viewer (refactored)
│       │   ├── SpatialPanoramaView.swift
│       │   ├── PanoramaImageStitcher.swift
│       │   ├── PanoramaCameraController.swift
│       │   └── PanoramaConfiguration.swift
│       ├── Components/          # Reusable 3D components
│       │   ├── RoomSceneView.swift
│       │   ├── PhotoNodeBuilder.swift
│       │   └── OrbitCamera.swift
│       └── Documentation/
├── Resources/                    # Assets and resources
└── Documentation/                # Architecture and implementation guides
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

## Roadmap & Next Steps

### 🔴 High Priority

#### 1. Unit Testing Coverage
**Status:** ⚠️ Minimal test coverage

**What's needed:**
- [ ] **PersistenceService tests** - File I/O operations, error handling
- [ ] **PermissionsManager tests** - Authorization state handling
- [ ] **ViewModel tests** - Business logic, state management
- [ ] **Model tests** - Codable conformance, data integrity
- [ ] **Mock implementations** - For dependency injection testing

**Why it matters:**
- Prevent regressions during refactoring
- Validate edge cases (missing files, permission denial)
- Enable confident code changes
- Document expected behavior

**Files to test:**
```
RoomPlanApp/Services/PersistenceService.swift
RoomPlanApp/Services/PermissionsManager.swift
RoomPlanApp/Modules/*/ViewModels/*.swift
RoomPlanApp/Models/*.swift
```

#### 2. Panorama Stitching Quality
**Status:** 🟡 Working but could be better

**Current state:**
- ✅ No gaps between photos
- ✅ No double vision/ghosting
- ✅ Subtle seam softening (4px)
- ⚠️ Simple overlay stitching (photos drawn on top)
- ⚠️ Black space at top/bottom (photos don't cover full vertical range)

**Improvements needed:**
- [ ] **Fill top/bottom black space** - Stretch nearest photos or use gradient fill
  ```
  Current state:
  ┌─────────────────────┐
  │   BLACK (ceiling)   │ ← No photos point straight up
  ├─────────────────────┤
  │                     │
  │   PHOTOS (-31° to   │ ← Photos cover this range
  │      +12° elev)     │
  │                     │
  ├─────────────────────┤
  │   BLACK (floor)     │ ← No photos point straight down
  └─────────────────────┘

  Fill options:
  1. Stretch nearest photos to cover poles (simple, may distort)
  2. Generate gradient blend to solid color (smooth fade)
  3. Smart content-aware fill using photo edges (advanced)
  4. Cap with dominant color from photo edges (clean)
  ```
- [ ] **Async stitching** - Move to background thread with progress indicator
- [ ] **Image caching** - Save generated equirectangular images to disk
- [ ] **Adaptive sizing** - Calculate photo size based on distribution
- [ ] **Multi-band blending** - Professional seam elimination (like Photoshop)
- [ ] **Color correction** - Match brightness/color between adjacent photos

**See:** `RoomPlanApp/Modules/Viewer/Documentation/VIEWER_IMPLEMENTATION.md` - Stitching Quality Improvements section

#### 3. Photo Display Enhancements in 3D Viewer
**Status:** ✅ Photos already mapped to walls, could be enhanced

**Current implementation (WORKING):**
- ✅ Actual photos displayed as textured planes (not just spheres)
- ✅ Photos mapped to nearest wall using ray-plane intersection
- ✅ Oriented correctly to face outward from walls
- ✅ Positioned with staggered offset to prevent z-fighting
- ✅ Scaled appropriately (2m tall or 80% of wall height)
- ✅ Slight transparency (98%) to see wall geometry behind

**See:** `RoomPlanApp/Modules/Viewer/Utilities/PhotoNodeBuilder.swift`

**Potential enhancements:**
- [ ] **Interactive photo selection** - Tap photo to view full-screen
- [ ] **Photo filtering** - Toggle photo visibility on/off
- [ ] **Photo metadata overlay** - Show capture date/time on hover
- [ ] **Thumbnail preview** - Show smaller thumbnails with option to enlarge
- [ ] **Photo grouping** - Group photos by wall or by capture session
- [ ] **Better overlap handling** - Detect and handle overlapping photos more elegantly

---

### 🟡 Medium Priority

#### 4. Dashboard Enhancements
**What's missing:**
- [ ] **Delete scans** - Swipe-to-delete with confirmation
- [ ] **Edit scan names** - Tap to rename scans
- [ ] **Search/filter** - Find scans by name or date
- [ ] **Sort options** - By name, date, photo count
- [ ] **Scan preview** - Thumbnail of 3D model or first photo
- [ ] **Storage stats** - Show disk usage per scan

#### 5. Export & Sharing
**What's missing:**
- [ ] **AR Quick Look** - Share USDZ for AR preview
- [ ] **OBJ export** - Convert to OBJ format with textures
- [ ] **Photo export** - Export all photos as ZIP
- [ ] **Share button** - System share sheet integration
- [ ] **AirDrop support** - Direct device-to-device transfer

#### 6. Error Handling & Recovery
**What's missing:**
- [ ] **Graceful error messages** - User-friendly error descriptions
- [ ] **Retry mechanisms** - Auto-retry failed operations
- [ ] **Corrupted scan detection** - Validate and recover partial data
- [ ] **Low storage warnings** - Alert before running out of space
- [ ] **ARKit tracking loss** - Guide user to improve tracking

#### 7. Performance Optimizations
**What's needed:**
- [ ] **Lazy loading** - Don't load all scans on dashboard open
- [ ] **Thumbnail caching** - Generate and cache preview images
- [ ] **USDZ streaming** - Load 3D models progressively
- [ ] **Photo compression** - Reduce file sizes while maintaining quality
- [ ] **Background processing** - Export and save on background queue

---

### 🟢 Low Priority / Nice-to-Have

#### 8. Advanced Camera Features
- [ ] **Manual photo capture** - Button to take photos during scan
- [ ] **Photo editing** - Crop, rotate, adjust before saving
- [ ] **HDR capture** - Better lighting in difficult conditions
- [ ] **Burst mode** - Capture multiple photos quickly

#### 9. Panorama Viewer Enhancements
- [ ] **Gyroscope support** - Look around using device motion
- [ ] **VR mode** - Side-by-side view for VR headsets
- [ ] **Hotspot navigation** - Jump between photo locations
- [ ] **Measurement tools** - Measure distances in panorama
- [ ] **Annotations** - Add notes/markers in 3D space

#### 10. Project Management
- [ ] **Folders/Collections** - Organize scans into groups
- [ ] **Tags** - Add custom tags to scans
- [ ] **Notes** - Add descriptions and metadata
- [ ] **Multi-select** - Batch operations (delete, export)

#### 11. Cloud Sync (Future)
- [ ] **iCloud sync** - Sync scans across devices
- [ ] **Backup/restore** - Cloud backup of scans
- [ ] **Collaboration** - Share scans with others

---

## Known Issues

### Panorama Viewer
- ⚠️ **Black space at top/bottom** - Photos don't cover full vertical range (zenith/nadir)
  - **Cause:** Photos captured at eye level don't include straight up or down views
  - **Current:** Black areas visible when looking up or down
  - **Workaround:** Avoid looking straight up/down, or capture more photos at extreme elevations
  - **Fix planned:** Fill with stretched photos, gradients, or solid color caps

- ⚠️ **Seam visibility** - Slight seams visible in some lighting conditions
  - **Workaround:** Adjust `seamFeatherPixels` in `PanoramaConfiguration.swift`
  - **Fix planned:** Multi-band blending implementation

### Room Capture
- ⚠️ **ARKit tracking loss** - Can occur in low-light or featureless environments
  - **Workaround:** Ensure good lighting and visible features
  - **Fix planned:** Add visual tracking quality indicator

### Performance
- ⚠️ **Panorama stitching blocks UI** - 1-2 second freeze for 32 photos
  - **Workaround:** Capture fewer photos or wait for completion
  - **Fix planned:** Async stitching with progress indicator

---

## Contributing

When implementing new features:

1. **Follow existing patterns** - Use MVVM, protocol-based design, dependency injection
2. **Add documentation** - Update module documentation in `Documentation/` folders
3. **Write tests** - Add unit tests for new functionality
4. **Use Swift 6** - Enable strict concurrency, use @MainActor where needed
5. **Debug logging** - Add `debugPrint()` statements for major operations

**Code review checklist:**
- [ ] Follows MVVM architecture
- [ ] Uses protocols for dependencies
- [ ] Has @MainActor isolation where needed
- [ ] Includes error handling
- [ ] Has debug logging
- [ ] Documentation updated
- [ ] Tests added (when applicable)

---

## License

Internal use only - Arnlee Vizcayno
