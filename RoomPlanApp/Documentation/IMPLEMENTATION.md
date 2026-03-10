# Implementation Documentation

## Table of Contents

1. [Application Architecture](#application-architecture)
2. [Data Flow](#data-flow)
3. [RoomPlan Integration](#roomplan-integration)
4. [Photo Capture System](#photo-capture-system)
5. [Persistence Layer](#persistence-layer)
6. [3D Rendering](#3d-rendering)
7. [Concurrency & Threading](#concurrency--threading)
8. [Error Handling](#error-handling)
9. [State Management](#state-management)
10. [Permissions System](#permissions-system)

---

## Application Architecture

### MVVM Pattern Implementation

The application follows a strict MVVM (Model-View-ViewModel) architecture with dependency injection for all service dependencies.

#### Layer Responsibilities

**Models (Data Layer)**
- Pure data structures
- No business logic
- Codable conformance for persistence
- Observable conformance for SwiftUI reactivity

**Views (Presentation Layer)**
- SwiftUI declarative UI
- No business logic
- Binds to ViewModel published properties
- Calls ViewModel methods for actions

**ViewModels (Business Logic Layer)**
- Marked with `@MainActor` for UI thread safety
- Conform to protocol interfaces for testability
- Coordinate between services and views
- Manage UI state and error states

**Services (Shared Functionality)**
- Singleton instances for app-wide access
- Protocol-based for dependency injection
- No `@MainActor` isolation (thread-agnostic)
- Stateless operations

### Directory Structure

```
RoomPlanApp/
├── App/
│   └── RoomPlanAppApp.swift           # App entry point
├── Models/
│   ├── RoomScan.swift                 # Main scan model (@Observable class)
│   ├── ScanPhoto.swift                # Photo with spatial pose
│   └── SpatialPose.swift              # 3D position + quaternion
├── Services/
│   ├── PersistenceService.swift       # File I/O operations
│   ├── PermissionsManager.swift       # Camera/ARKit permissions
│   ├── AppConfiguration.swift         # App constants
│   └── Protocols/
│       ├── PersistenceProtocol.swift
│       └── PermissionsProtocol.swift
├── Modules/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── DashboardViewModel.swift
│   │   └── DashboardViewModelProtocol.swift
│   ├── RoomCapture/
│   │   ├── RoomCaptureView.swift
│   │   ├── RoomCaptureViewModel.swift
│   │   ├── RoomCaptureViewModelProtocol.swift
│   │   ├── RoomCaptureViewRepresentable.swift
│   │   └── RoomCaptureCoordinator.swift
│   └── Viewer/
│       ├── RoomViewerView.swift
│       ├── RoomViewerViewModel.swift
│       └── RoomViewerViewModelProtocol.swift
└── Resources/
    └── Assets.xcassets/
```

---

## Data Flow

### Complete User Journey

#### 1. App Launch → Dashboard

```
App Launch
    ↓
RoomPlanAppApp.swift creates ContentView
    ↓
ContentView = NavigationStack { DashboardView() }
    ↓
DashboardView creates DashboardViewModel
    ↓
.task { viewModel.loadScans() }
    ↓
DashboardViewModel → PersistenceService.loadAllScans()
    ↓
Scans loaded and sorted by date
    ↓
SwiftUI updates list UI
```

#### 2. Start Room Scan

```
User taps camera button
    ↓
DashboardView sets showingScanner = true
    ↓
.fullScreenCover presents NavigationStack { RoomCaptureView }
    ↓
RoomCaptureView.init() creates RoomCaptureViewModel
    ↓
RoomCaptureViewModel.init(onComplete: { scan in ... })
    ↓
View loads → RoomCaptureViewRepresentable created
    ↓
RoomCaptureViewController.viewDidLoad()
    ↓
Creates RoomPlan.RoomCaptureView
    ↓
ViewModel.createCoordinator(captureSession)
    ↓
RoomCaptureCoordinator created and set as session delegate
```

#### 3. Room Scanning Flow

```
RoomCaptureViewController.viewDidAppear()
    ↓
ViewModel.checkPermissions() async
    ↓
PermissionsManager.checkRoomScanRequirements()
    ├─ Check ARKit support
    ├─ Check LiDAR availability
    └─ Request camera permission
    ↓
If permissions granted:
    ViewModel.startCapture()
    ↓
    Coordinator.startCapture()
    ↓
    RoomCaptureSession.run(configuration)
    ↓
    User moves device around room
    ↓
    Delegate callbacks fired:
    captureSession(_:didUpdate:)
        ↓
        Coordinator → ViewModel.handleRoomUpdated()
        ↓
        capturedRoom = updatedRoom
        canExport = true
```

#### 4. Photo Capture During Scan

```
User taps "Take Photo" button
    ↓
RoomCaptureView calls: Task { await viewModel.capturePhoto() }
    ↓
ViewModel.capturePhoto() async
    ↓
Get ARSession from coordinator.arSession
    ↓
Get current frame: arSession.currentFrame
    ↓
Extract camera transform (4x4 matrix):
    - position: SIMD3(columns.3.x, .y, .z)
    - orientation: simd_quatf(transform)
    ↓
Create SpatialPose(position, orientation)
    ↓
Extract pixel buffer: frame.capturedImage
    ↓
Convert to CIImage
    ↓
Rotate .right (portrait mode)
    ↓
Create CGImage via CIContext
    ↓
Create UIImage with scale=1.0, orientation=.up
    ↓
Append (image, pose) to capturedPhotos array
    ↓
UI updates: photo count badge increments
```

#### 5. Finish and Save Scan

```
User taps "Finish" button
    ↓
Generate default name: "Room Scan X"
    ↓
Show alert dialog with TextField
    ↓
User enters name, taps "Save"
    ↓
ViewModel.finishCapture(withName: name)
    ↓
Coordinator.stopCapture()
    ↓
Task { await saveCompletedScan(room, name) }
    ↓
saveCompletedScan() async:
    ├─ exportRoomToUSDZ(room) async throws -> Data
    │   ↓
    │   Task.detached (background queue):
    │       ├─ Create temp URL
    │       ├─ room.export(to: usdzURL)
    │       ├─ Verify file exists
    │       ├─ Read Data
    │       └─ Delete temp file
    │   ↓
    │   Returns USDZ Data
    │
    └─ persistenceService.saveCompletedScan(name, usdzData, photos)
        ↓
        PersistenceService.saveCompletedScan():
            ├─ Create scan directory: Documents/RoomScans/{uuid}/
            ├─ Write USDZ: {uuid}/room.usdz
            ├─ Create photos directory: {uuid}/photos/
            ├─ For each photo:
            │   ├─ Compress to JPEG (quality=0.85)
            │   ├─ Write: photos/{photo-uuid}.jpg
            │   └─ Create ScanPhoto model
            ├─ Create RoomScan model
            ├─ Encode to JSON
            └─ Write: {uuid}/scan.json
        ↓
        Returns saved RoomScan
    ↓
handleSaveSuccess(scan)
    ↓
onComplete(scan) callback fires
    ↓
DashboardView dismisses scanner
    ↓
DashboardView.viewModel.loadScans()
    ↓
List updates with new scan
```

#### 6. View Scan in 3D

```
User taps scan row
    ↓
DashboardView sets selectedScan = scan, showingViewer = true
    ↓
.navigationDestination presents RoomViewerView(scan: scan)
    ↓
RoomViewerView creates RoomViewerViewModel(scan)
    ↓
SceneKit scene created:
    ├─ SCNScene()
    ├─ Camera node at origin
    ├─ Load USDZ model from scan.usdURL
    ├─ Add model to scene
    └─ For each photo in scan.photos:
        └─ Create debug sphere at photo.cameraPose.position
    ↓
User can orbit/zoom/pan with gestures
```

---

## RoomPlan Integration

### RoomCaptureSession Lifecycle

RoomPlan provides `RoomCaptureView` which internally creates and manages a `RoomCaptureSession`.

#### Initialization Flow

```swift
// 1. Create RoomPlan's capture view (owns the session)
let captureView = RoomPlan.RoomCaptureView(frame: view.bounds)

// 2. Access the internal session
let session = captureView.captureSession

// 3. Create coordinator as session delegate
let coordinator = RoomCaptureCoordinator(
    captureSession: session,
    onUpdate: { room in /* ... */ },
    onError: { error in /* ... */ }
)

// 4. Set coordinator as delegate
session.delegate = coordinator

// 5. Start scanning
let config = RoomCaptureSession.Configuration()
session.run(configuration: config)
```

#### RoomCaptureSessionDelegate Methods

**Primary Callbacks (Used):**

```swift
// Called continuously as room geometry updates
func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
    // Updates VM state: capturedRoom = room, canExport = true
}

// Called when session ends (user stops or error)
func captureSession(_ session: RoomCaptureSession,
                    didEndWith data: CapturedRoomData,
                    error: Error?) {
    // Handle completion or error
}

// Called when session starts
func captureSession(_ session: RoomCaptureSession,
                    didStartWith configuration: Configuration) {
    // Log successful start
}
```

**Secondary Callbacks (Logged but not used):**

```swift
func captureSession(_ session: RoomCaptureSession, didAdd room: CapturedRoom)
func captureSession(_ session: RoomCaptureSession, didChange room: CapturedRoom)
func captureSession(_ session: RoomCaptureSession, didRemove room: CapturedRoom)
func captureSession(_ session: RoomCaptureSession,
                    didProvide instruction: Instruction)
```

### CapturedRoom → USDZ Export

```swift
private func exportRoomToUSDZ(_ room: CapturedRoom) async throws -> Data {
    try await Task.detached {
        // Create temp file URL
        let usdzURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).usdz")

        // Export (runs on background queue automatically)
        try await room.export(to: usdzURL)

        // Verify file exists
        guard FileManager.default.fileExists(atPath: usdzURL.path) else {
            throw NSError(domain: "RoomCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Export succeeded but file not found"
            ])
        }

        // Read data into memory
        let data = try Data(contentsOf: usdzURL)

        // Clean up temp file
        try? FileManager.default.removeItem(at: usdzURL)

        return data
    }.value
}
```

**Why Task.detached?**
- RoomPlan's `export(to:)` is CPU-intensive
- Runs on background queue to avoid blocking MainActor
- Returns to MainActor context after completion via `.value`

### ARSession Access

RoomPlan's `RoomCaptureView` creates its own `ARSession` internally. We access it for photo capture:

```swift
// Get ARSession reference
let arSession = captureView.captureSession.arSession

// Access current frame for photo capture
guard let frame = arSession.currentFrame else { return }

// Extract camera transform
let transform = frame.camera.transform  // simd_float4x4
let position = SIMD3<Float>(
    transform.columns.3.x,
    transform.columns.3.y,
    transform.columns.3.z
)
let orientation = simd_quatf(transform)

// Extract pixel buffer
let pixelBuffer = frame.capturedImage  // CVPixelBuffer
```

---

## Photo Capture System

### Camera Pose Extraction

ARKit provides camera poses as 4x4 transformation matrices. We extract position and orientation:

#### Matrix Structure

```
simd_float4x4 transform:
┌                           ┐
│ r00  r01  r02  position.x │  ← Rotation + Translation
│ r10  r11  r12  position.y │
│ r20  r21  r22  position.z │
│  0    0    0       1      │
└                           ┘
```

#### Position Extraction

```swift
let position = SIMD3<Float>(
    transform.columns.3.x,  // X coordinate (right/left)
    transform.columns.3.y,  // Y coordinate (up/down)
    transform.columns.3.z   // Z coordinate (forward/back)
)
```

#### Orientation Extraction (Quaternion)

```swift
// Convert rotation matrix to quaternion
let orientation = simd_quatf(transform)

// Quaternion components:
// - orientation.real      = w (scalar part)
// - orientation.imag.x    = x (vector i)
// - orientation.imag.y    = y (vector j)
// - orientation.imag.z    = z (vector k)
```

**Why Quaternions?**
- No gimbal lock (unlike Euler angles)
- Efficient interpolation for animations
- Standard representation in 3D graphics
- ARKit coordinate system compatible
- Compact storage (4 floats vs 9 for matrix)

### Image Processing Pipeline

```swift
func capturePhoto() async {
    // 1. Get pixel buffer from ARKit frame
    let pixelBuffer: CVPixelBuffer = frame.capturedImage

    // 2. Convert to CIImage
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

    // 3. Rotate for portrait orientation
    // ARKit captures in landscape, need portrait
    let rotated = ciImage.oriented(.right)  // 90° clockwise

    // 4. Create CIContext for rendering
    let context = CIContext()

    // 5. Render to CGImage
    guard let cgImage = context.createCGImage(
        rotated,
        from: rotated.extent
    ) else {
        throw NSError(/* conversion failed */)
    }

    // 6. Create final UIImage
    let image = UIImage(
        cgImage: cgImage,
        scale: AppConfiguration.Image.defaultScale,  // 1.0
        orientation: .up
    )

    // 7. Store in memory with pose
    capturedPhotos.append((image: image, pose: cameraPose))
}
```

**Why .oriented(.right)?**
- ARKit captures in UIDeviceOrientation.landscapeRight
- App runs in portrait mode
- .right rotation = 90° clockwise = correct portrait orientation

### In-Memory Storage Strategy

Photos are stored in memory during scanning:

```swift
// ViewModel property
var capturedPhotos: [(image: UIImage, pose: SpatialPose)] = []
```

**Why in-memory?**
1. Fast access during scanning
2. No disk I/O during time-critical AR session
3. Batch save at completion (atomic operation)
4. Easy to discard if user cancels

**Memory Considerations:**
- Full-resolution images: ~1-2 MB each (compressed)
- Typical scan: 5-10 photos = 10-20 MB total
- Acceptable for modern iOS devices (minimum 3GB RAM)

### Photo Compression and Storage

```swift
// Compress to JPEG when saving
guard let imageData = image.jpegData(
    compressionQuality: AppConfiguration.Image.jpegCompressionQuality  // 0.85
) else {
    throw PersistenceError.imageCompressionFailed
}

// Write to disk
try imageData.write(to: photoURL)
```

**Compression Quality: 0.85**
- Balance between quality and file size
- Typical result: 1.5-2 MB per photo
- Visually lossless for most use cases
- Reduces storage by ~50% vs quality 1.0

---

## Persistence Layer

### File System Structure

```
Documents/
└── RoomScans/
    ├── {scan-uuid-1}/
    │   ├── scan.json              # Metadata
    │   ├── room.usdz              # 3D model
    │   └── photos/
    │       ├── {photo-uuid-1}.jpg
    │       ├── {photo-uuid-2}.jpg
    │       └── ...
    │
    ├── {scan-uuid-2}/
    │   ├── scan.json
    │   ├── room.usdz
    │   └── photos/
    │       └── ...
    └── ...
```

### scan.json Format

```json
{
  "id": "3F2504E0-4F89-41D3-9A0C-0305E82C3301",
  "name": "Living Room",
  "usdURL": "file:///path/to/scan-uuid/room.usdz",
  "captureDate": "2026-03-10T12:30:00Z",
  "directory": "file:///path/to/scan-uuid/",
  "photos": [
    {
      "id": "A1B2C3D4-...",
      "imageURL": "file:///path/to/photos/photo-uuid.jpg",
      "captureDate": "2026-03-10T12:31:00Z",
      "targetSurfaceID": null,
      "cameraPose": {
        "position": [1.5, 1.2, -0.8],
        "orientation": [0.0, 0.707, 0.0, 0.707]
      }
    }
  ]
}
```

### Path Resolution Strategy

**Problem:** File paths change after app reinstall (container UUID changes)

**Solution:** Store relative paths, resolve on load

```swift
private func loadScan(from directory: URL) throws -> RoomScan {
    // Load JSON
    let data = try Data(contentsOf: directory.appendingPathComponent("scan.json"))
    var scan = try JSONDecoder().decode(RoomScan.self, from: data)

    // Update paths to current app container
    updateScanPaths(&scan)

    return scan
}

private func updateScanPaths(_ scan: inout RoomScan) {
    // Resolve scan directory
    scan.directory = scansDirectory.appendingPathComponent(
        scan.id.uuidString,
        isDirectory: true
    )

    // Resolve USDZ path
    scan.usdURL = scan.directory.appendingPathComponent(
        AppConfiguration.FileSystem.roomModelFilename  // "room.usdz"
    )

    // Resolve photo paths
    updatePhotoURLs(&scan)
}

private func updatePhotoURLs(_ scan: inout RoomScan) {
    guard !scan.photos.isEmpty else { return }

    let photosDir = scan.directory.appendingPathComponent(
        AppConfiguration.FileSystem.photosDirectoryName,  // "photos"
        isDirectory: true
    )

    for i in 0..<scan.photos.count {
        let photoID = scan.photos[i].id
        scan.photos[i].imageURL = photosDir
            .appendingPathComponent("\(photoID.uuidString).jpg")
    }
}
```

### Atomic Save Operations

```swift
func saveCompletedScan(
    name: String,
    usdzData: Data,
    photos: [(image: UIImage, pose: SpatialPose)]
) throws -> RoomScan {
    // 1. Create directory structure
    let scanID = UUID()
    let scanDir = scansDirectory.appendingPathComponent(
        scanID.uuidString,
        isDirectory: true
    )
    try fileManager.createDirectory(
        at: scanDir,
        withIntermediateDirectories: true
    )

    // 2. Write USDZ (critical file - fail early if this fails)
    let roomURL = scanDir.appendingPathComponent("room.usdz")
    try usdzData.write(to: roomURL)

    // 3. Create photos directory
    let photosDir = scanDir.appendingPathComponent(
        "photos",
        isDirectory: true
    )
    try fileManager.createDirectory(
        at: photosDir,
        withIntermediateDirectories: true
    )

    // 4. Save photos
    var savedPhotos: [ScanPhoto] = []
    for (index, photoData) in photos.enumerated() {
        let photoID = UUID()
        let photoURL = photosDir.appendingPathComponent("\(photoID).jpg")

        // Compress
        guard let imageData = photoData.image.jpegData(
            compressionQuality: 0.85
        ) else {
            throw PersistenceError.imageCompressionFailed
        }

        // Write
        try imageData.write(to: photoURL)

        // Create model
        savedPhotos.append(ScanPhoto(
            id: photoID,
            imageURL: photoURL,
            cameraPose: photoData.pose,
            captureDate: Date(),
            targetSurfaceID: nil
        ))
    }

    // 5. Create scan model
    let scan = RoomScan(
        id: scanID,
        name: name,
        usdURL: roomURL,
        captureDate: Date(),
        photos: savedPhotos,
        directory: scanDir
    )

    // 6. Write metadata JSON (last step)
    try saveScan(scan)

    return scan
}
```

**Why this order?**
1. USDZ first (largest file, most likely to fail)
2. Photos next (batch operation)
3. JSON last (small, fast, atomic marker of completion)

If any step fails, the directory exists but has no `scan.json`, so it's ignored on next load.

---

## 3D Rendering

### SceneKit Scene Setup

```swift
func makeUIView(context: Context) -> SCNView {
    let sceneView = SCNView()
    let scene = SCNScene()
    sceneView.scene = scene
    sceneView.backgroundColor = .black

    // Camera setup
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 60
    cameraNode.position = SCNVector3(0, 1.5, 3)
    scene.rootNode.addChildNode(cameraNode)

    // Enable user interaction
    sceneView.allowsCameraControl = true
    sceneView.autoenablesDefaultLighting = true

    // Load USDZ model
    loadRoomModel(into: scene)

    // Add captured photos as image planes
    let photoNodes = createScanPhotoNodes(scanPhotos: scan.photos, roomScene: scene)
    photoNodes.forEach { scene.rootNode.addChildNode($0) }

    return sceneView
}
```

### USDZ Model Loading

```swift
private func loadRoomModel(into scene: SCNScene) {
    guard let modelScene = try? SCNScene(
        url: scan.usdURL,
        options: [.checkConsistency: true]
    ) else {
        debugPrint("Failed to load USDZ model")
        return
    }

    // Add all nodes from USDZ to main scene
    for node in modelScene.rootNode.childNodes {
        scene.rootNode.addChildNode(node)
    }
}
```

### Captured Photo Display

The viewer displays captured photos as image planes positioned in 3D space:

```swift
private func createScanPhotoNodes(scanPhotos: [ScanPhoto], roomScene: SCNScene?) -> [SCNNode] {
    var photoNodes: [SCNNode] = []

    // Extract walls from room scene if available
    let walls = roomScene != nil ? extractWalls(from: roomScene!) : []

    for (index, photo) in scanPhotos.enumerated() {
        // Load image
        guard let imageData = try? Data(contentsOf: photo.imageURL),
              let image = UIImage(data: imageData) else {
            continue
        }

        // Create photo node
        let photoNode: SCNNode
        if !walls.isEmpty {
            // Map photo to nearest wall (with index for z-offset)
            photoNode = createPhotoOnWall(
                image: image,
                cameraPose: photo.cameraPose,
                walls: walls,
                photoIndex: index
            )
        } else {
            // No walls, position at camera pose
            photoNode = createPhotoAtPose(
                image: image,
                cameraPose: photo.cameraPose
            )
        }

        photoNode.name = "scan_photo_\(photo.id.uuidString)"
        photoNode.renderingOrder = index  // Prevent z-fighting
        photoNodes.append(photoNode)
    }

    return photoNodes
}
```

**Two rendering modes:**
1. **Wall-mapped mode**: Photos are mapped to the nearest wall surface extracted from the USDZ model
2. **Pose-positioned mode**: Photos are positioned at their original camera capture positions (fallback when no walls detected)

### Camera Controls

SceneKit provides built-in camera controls via `allowsCameraControl = true`:

- **Rotate:** One-finger drag
- **Pan:** Two-finger drag
- **Zoom:** Pinch gesture
- **Reset:** Double-tap

These controls automatically modify the camera node's transform.

---

## Concurrency & Threading

### MainActor Isolation

All ViewModels are isolated to MainActor:

```swift
@MainActor
@Observable
final class DashboardViewModel: DashboardViewModelProtocol {
    // All properties and methods run on main thread
    // Safe to update UI-bound properties
}
```

**Why @MainActor?**
- All UI updates must happen on main thread
- SwiftUI's `@Observable` requires main thread updates
- Prevents data races on published properties
- Compiler enforces thread safety

### Service Layer Threading

Services are NOT MainActor-isolated:

```swift
final class PersistenceService: Sendable {
    static let shared = PersistenceService()

    // Methods can run on any thread
    func loadAllScans() throws -> [RoomScan] {
        // File I/O can happen on background thread
        // Caller (ViewModel) is responsible for MainActor dispatch
    }
}
```

**Why not @MainActor?**
- File I/O should not block main thread
- Allows background processing
- ViewModels control threading via Task/async

### Async/Await Patterns

#### ViewModel → Service Calls

```swift
// In ViewModel (@MainActor)
func loadScans() {
    isLoading = true  // Main thread update

    do {
        // File I/O happens synchronously
        // We're already on MainActor, so stays on main thread
        scans = try persistenceService.loadAllScans()
        scans.sort { $0.captureDate > $1.captureDate }
    } catch {
        errorMessage = error.localizedDescription
    }

    isLoading = false  // Main thread update
}
```

#### Background Work with Task.detached

```swift
// Export USDZ on background queue
private func exportRoomToUSDZ(_ room: CapturedRoom) async throws -> Data {
    try await Task.detached {
        // This entire block runs on background queue
        let usdzURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).usdz")

        try await room.export(to: usdzURL)
        let data = try Data(contentsOf: usdzURL)
        try? FileManager.default.removeItem(at: usdzURL)

        return data
    }.value  // Automatically switches back to calling context (MainActor)
}

// Called from MainActor context
private func saveCompletedScan(_ room: CapturedRoom, withName name: String) async {
    isSaving = true  // MainActor

    do {
        // Runs on background, returns to MainActor
        let usdzData = try await exportRoomToUSDZ(room)

        // Back on MainActor, can update UI properties
        let scan = try persistenceService.saveCompletedScan(
            name: name,
            usdzData: usdzData,
            photos: capturedPhotos
        )

        handleSaveSuccess(scan)  // MainActor
    } catch {
        handleSaveError(error)  // MainActor
    }
}
```

### Permission Checks (Async)

```swift
func checkPermissions() async -> Bool {
    // Calls PermissionsManager methods
    let result = await permissionsManager.checkRoomScanRequirements()

    if !result.isSuccess {
        // Update UI property (we're on MainActor)
        errorMessage = result.errorMessage
        return false
    }

    return true
}
```

**Why async?**
- Permission dialogs are asynchronous
- AVFoundation.requestAccess(for:) uses completion handlers
- We wrap in async/await for cleaner syntax

---

## Error Handling

### Error Types

#### PersistenceError

```swift
enum PersistenceError: LocalizedError {
    case scanNotFound
    case imageCompressionFailed
    case invalidData
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .scanNotFound:
            return "Scan not found"
        case .imageCompressionFailed:
            return "Failed to compress image"
        case .fileNotFound:
            return "File not found after writing"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
```

#### RequirementCheckResult

```swift
enum RequirementCheckResult {
    case success
    case failure(message: String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self { return message }
        return nil
    }
}
```

### Error Propagation Pattern

```swift
// Service throws errors
func loadAllScans() throws -> [RoomScan] {
    // File operations that can throw
}

// ViewModel catches and converts to UI state
func loadScans() {
    isLoading = true
    errorMessage = nil  // Clear previous error

    do {
        scans = try persistenceService.loadAllScans()
    } catch {
        // Convert to user-friendly message
        errorMessage = "Failed to load scans: \(error.localizedDescription)"
        debugPrint("📋 [DashboardVM] ❌ \(error)")
    }

    isLoading = false
}

// View displays error
.alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
    Button("OK") {
        viewModel.errorMessage = nil
    }
} message: {
    if let error = viewModel.errorMessage {
        Text(error)
    }
}
```

### Debug Logging Strategy

All components use emoji-prefixed debug logs:

```swift
debugPrint("📋 [DashboardVM] Loading scans...")      // Dashboard
debugPrint("🏠 [RoomCaptureVM] Starting capture...")  // Room Capture
debugPrint("📸 [RoomCaptureVM] Photo captured!")      // Photo Capture
debugPrint("💾 [PersistenceService] Saving scan...")  // Persistence
debugPrint("🎯 [RoomCaptureCoordinator] Session started") // Coordinator
debugPrint("🔐 [PermissionsManager] Checking permissions...") // Permissions
debugPrint("🎨 [RoomViewerVM] Initialized")          // Viewer
```

**Benefits:**
- Easy visual scanning of logs
- Component identification at a glance
- Consistent formatting
- Success (✅) and failure (❌) indicators

---

## State Management

### Observable Pattern

All ViewModels use Swift's `@Observable` macro:

```swift
@MainActor
@Observable
final class DashboardViewModel {
    var scans: [RoomScan] = []
    var isLoading = false
    var errorMessage: String?

    // Property changes automatically trigger SwiftUI updates
}
```

### State Properties

#### UI State

```swift
// Loading indicators
var isLoading: Bool
var isSaving: Bool
var isProcessing: Bool

// User feedback
var errorMessage: String?

// Capability flags
var canExport: Bool
var isCapturing: Bool
```

#### Data State

```swift
// Collections
var scans: [RoomScan]
var capturedPhotos: [(image: UIImage, pose: SpatialPose)]

// Single items
var capturedRoom: CapturedRoom?
var scan: RoomScan
```

### State Transitions

#### Dashboard States

```
┌─────────┐
│ Initial │ isLoading=false, scans=[], errorMessage=nil
└────┬────┘
     │ loadScans()
     ↓
┌─────────┐
│ Loading │ isLoading=true, scans=[], errorMessage=nil
└────┬────┘
     │
     ├─ Success
     │    ↓
     │  ┌─────────┐
     │  │ Loaded  │ isLoading=false, scans=[...], errorMessage=nil
     │  └─────────┘
     │
     └─ Failure
          ↓
        ┌───────┐
        │ Error │ isLoading=false, scans=[], errorMessage="..."
        └───────┘
```

#### Room Capture States

```
┌─────────────┐
│ Initialized │ isCapturing=false, canExport=false
└──────┬──────┘
       │ checkPermissions() → startCapture()
       ↓
┌──────────┐
│ Scanning │ isCapturing=true, canExport=false
└─────┬────┘
      │ Room data received
      ↓
┌─────────────┐
│ Ready       │ isCapturing=true, canExport=true
└──────┬──────┘
       │ finishCapture()
       ↓
┌─────────┐
│ Saving  │ isSaving=true, isCapturing=false
└────┬────┘
     │
     ├─ Success → onComplete(scan)
     └─ Failure → errorMessage set
```

### View Binding

SwiftUI automatically observes `@Observable` properties:

```swift
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading scans...")
            } else if viewModel.scans.isEmpty {
                emptyStateView
            } else {
                scanListView
            }
        }
        // View automatically updates when viewModel properties change
    }
}
```

---

## Permissions System

### Required Permissions

1. **Camera Access** - For photo capture during scanning
2. **ARKit Support** - Device capability check
3. **LiDAR Sensor** - Required for RoomPlan scanning

### Permission Flow

```swift
func checkRoomScanRequirements() async -> RequirementCheckResult {
    // 1. Check ARKit support (device capability)
    guard isARKitSupported else {
        return .failure(message: "This device doesn't support ARKit")
    }

    // 2. Check LiDAR support (hardware requirement)
    guard hasLiDARSupport else {
        return .failure(message:
            "This device doesn't have a LiDAR sensor. " +
            "Room scanning requires iPhone 12 Pro or later, " +
            "or iPad Pro (2020 or later)."
        )
    }

    // 3. Check camera permission
    let cameraStatus = await checkCameraPermission()
    guard cameraStatus == .authorized else {
        return .failure(message:
            "Camera access is required. " +
            "Please enable it in Settings."
        )
    }

    return .success
}
```

### Camera Permission Request

```swift
func checkCameraPermission() async -> PermissionStatus {
    let status = AVCaptureDevice.authorizationStatus(for: .video)

    switch status {
    case .authorized:
        return .authorized

    case .denied, .restricted:
        return .denied

    case .notDetermined:
        // Request permission (shows system dialog)
        let granted = await requestCameraPermission()
        return granted ? .authorized : .denied

    @unknown default:
        return .denied
    }
}

func requestCameraPermission() async -> Bool {
    await withCheckedContinuation { continuation in
        AVCaptureDevice.requestAccess(for: .video) { granted in
            continuation.resume(returning: granted)
        }
    }
}
```

### ARKit Capability Checks

```swift
var isARKitSupported: Bool {
    ARWorldTrackingConfiguration.isSupported
}

var hasLiDARSupport: Bool {
    ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
}
```

### Info.plist Requirements

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to capture photos during room scanning</string>
```

---

## Performance Considerations

### Memory Management

#### Photo Storage
- Photos stored in memory during scan: ~10-20 MB total
- Released after save completes
- USDZ export happens in detached task (separate memory pool)

#### USDZ Loading
- SceneKit loads USDZ models lazily
- Geometry data loaded on-demand
- Use `.checkConsistency` option to validate before loading

### CPU Optimization

#### Background Processing
```swift
// USDZ export on background queue
Task.detached {
    try await room.export(to: url)
}

// Image compression
let imageData = image.jpegData(compressionQuality: 0.85)
```

#### Batch Operations
```swift
// Save all photos in single operation
for photo in photos {
    try imageData.write(to: photoURL)
}
```

### Disk I/O Optimization

#### Sequential Writes
```swift
// 1. Create directory
// 2. Write USDZ (largest file first)
// 3. Write photos
// 4. Write JSON (small, fast, completion marker)
```

#### File Size Estimates
- USDZ model: 1-5 MB (depends on room complexity)
- Photo (compressed): 1.5-2 MB each
- JSON metadata: < 10 KB
- Total per scan: 10-30 MB

---

## Testing Integration Points

### Mock Service Implementations

```swift
class MockPersistenceService: PersistenceProtocol {
    var savedScans: [RoomScan] = []

    func saveCompletedScan(
        name: String,
        usdzData: Data,
        photos: [(UIImage, SpatialPose)]
    ) throws -> RoomScan {
        // Create in-memory scan without file I/O
        let scan = RoomScan(/* ... */)
        savedScans.append(scan)
        return scan
    }

    // Other protocol methods...
}
```

### Protocol Boundaries

All major components have protocol interfaces:
- `DashboardViewModelProtocol`
- `RoomCaptureViewModelProtocol`
- `RoomViewerViewModelProtocol`
- `PersistenceProtocol`
- `PermissionsProtocol`

This enables full unit testing without AR hardware or file system access.

---

## Future Enhancement Points

### Planned Improvements

1. **Panorama Photo Stitching**
   - Full 360° equirectangular stitching
   - GPU-accelerated with Metal
   - Add to viewer for immersive mode

2. **Enhanced Photo-to-Wall Mapping** ✅ PARTIALLY IMPLEMENTED
   - ✅ Basic wall extraction from USDZ model
   - ✅ Map photos to nearest walls
   - 🔄 Advanced surface alignment with orientation
   - 🔄 Interactive photo placement/editing

3. **Cloud Sync**
   - Upload scans to iCloud
   - Share between devices
   - Collaborative scanning

4. **Export Options**
   - Export as OBJ/FBX
   - Share via AirDrop
   - Generate PDF floor plans

### Extension Points

#### Custom Coordinators
```swift
protocol RoomCaptureCoordinatorProtocol {
    func startCapture()
    func stopCapture()
    var arSession: ARSession { get }
}
```

#### Pluggable Persistence
```swift
protocol PersistenceProtocol: Sendable {
    func loadAllScans() throws -> [RoomScan]
    func deleteScan(_ scan: RoomScan) throws
    func saveCompletedScan(
        name: String,
        usdzData: Data,
        photos: [(image: UIImage, pose: SpatialPose)]
    ) throws -> RoomScan

    // Easy to swap with CloudKit implementation
}
```

---

## Appendix: Key Files Reference

### Critical Paths

**App Entry:**
- `App/RoomPlanAppApp.swift` - App lifecycle

**Models:**
- `Models/RoomScan.swift` - Main scan model
- `Models/SpatialPose.swift` - Quaternion + position
- `Models/ScanPhoto.swift` - Photo with pose

**Services:**
- `Services/PersistenceService.swift` - File I/O
- `Services/PermissionsManager.swift` - Permissions
- `Services/AppConfiguration.swift` - Constants

**ViewModels:**
- `Modules/Dashboard/DashboardViewModel.swift`
- `Modules/RoomCapture/RoomCaptureViewModel.swift`
- `Modules/Viewer/RoomViewerViewModel.swift`

**Views:**
- `Modules/Dashboard/DashboardView.swift`
- `Modules/RoomCapture/RoomCaptureView.swift`
- `Modules/RoomCapture/RoomCaptureViewRepresentable.swift`
- `Modules/Viewer/RoomViewerView.swift`

**Coordinators:**
- `Modules/RoomCapture/RoomCaptureCoordinator.swift`

### Configuration Constants

**File:** `Services/AppConfiguration.swift`

```swift
AppConfiguration.Image.jpegCompressionQuality     // 0.85
AppConfiguration.Image.defaultScale               // 1.0
AppConfiguration.FileSystem.scansDirectoryName    // "RoomScans"
AppConfiguration.FileSystem.photosDirectoryName   // "photos"
AppConfiguration.FileSystem.scanMetadataFilename  // "scan.json"
AppConfiguration.FileSystem.roomModelFilename     // "room.usdz"
AppConfiguration.Naming.defaultRoomNamePrefix     // "Room Scan"
```

---

**End of Implementation Documentation**
