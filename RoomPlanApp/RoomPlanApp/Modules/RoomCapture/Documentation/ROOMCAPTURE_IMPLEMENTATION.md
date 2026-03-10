# RoomCapture Module

## Overview

The RoomCapture module handles the complete room scanning workflow, integrating Apple's RoomPlan framework with custom photo capture capabilities.

## Purpose

- Integrate RoomPlan SDK for 3D room scanning
- Capture photos at specific spatial positions during scanning
- Manage AR camera permissions and capabilities
- Handle room data export to USDZ format
- Coordinate between ARKit, RoomPlan, and app state

## Architecture

```
RoomCaptureView (SwiftUI UI Layer)
    ↓
RoomCaptureViewRepresentable (SwiftUI-UIKit Bridge)
    ↓
RoomCaptureViewController (UIKit Container)
    ├─ RoomPlan.RoomCaptureView (Apple's AR View)
    │   └─ RoomCaptureSession (Apple's SDK)
    └─ RoomCaptureCoordinator (Session Delegate)
        ↓
RoomCaptureViewModel (Business Logic)
    ├─ PersistenceService (File I/O)
    └─ PermissionsManager (Permissions)
```

## Files

- **RoomCaptureView.swift** - SwiftUI overlay UI (buttons, indicators)
- **RoomCaptureViewRepresentable.swift** - UIKit integration bridge
- **RoomCaptureViewModel.swift** - Business logic and state management
- **RoomCaptureViewModelProtocol.swift** - Protocol interface
- **RoomCaptureCoordinator.swift** - RoomPlan delegate handler

---

## File Responsibilities

### RoomCaptureView.swift

**Purpose:** SwiftUI overlay UI on top of RoomPlan's AR view

**Components:**
- Saving indicator (top center)
- Finish button (lower left)
- Photo counter (lower right, above Take Photo)
- Take Photo button (lower right)
- Error message display (bottom)
- Name entry dialog

**UI Layout:**
```
┌─────────────────────────────────┐
│   [Saving room scan...]        │ ← Top indicator
│                                 │
│                                 │
│    RoomPlan AR Camera View      │
│                                 │
│                                 │
│  [Finish]            [5 photos] │ ← Bottom controls
│              [Take Photo] ━┛    │
│                                 │
│    [Error message if any]       │
└─────────────────────────────────┘
```

**State Management:**
```swift
@State private var viewModel: RoomCaptureViewModel
@State private var showingNameDialog = false
@State private var roomName = ""
@Environment(\.dismiss) private var dismiss
```

### RoomCaptureViewRepresentable.swift

**Purpose:** Bridge between SwiftUI and UIKit

**Responsibilities:**
- Create RoomCaptureViewController
- Pass ViewModel reference
- Handle SwiftUI lifecycle

**Implementation:**
```swift
struct RoomCaptureViewRepresentable: UIViewControllerRepresentable {
    let viewModel: RoomCaptureViewModel

    func makeUIViewController(context: Context) -> RoomCaptureViewController {
        RoomCaptureViewController(viewModel: viewModel)
    }

    func updateUIViewController(_ uiViewController: RoomCaptureViewController,
                               context: Context) {
        // No updates needed - RoomPlan manages its own state
    }
}
```

### RoomCaptureViewController

**Purpose:** UIKit container for RoomPlan's view controller

**Lifecycle:**

1. **viewDidLoad()**
   - Create RoomPlan.RoomCaptureView
   - Add as subview with constraints
   - Create RoomCaptureCoordinator
   - Set coordinator as session delegate

2. **viewDidAppear()**
   - Check permissions
   - Start capture if authorized

3. **viewWillDisappear()**
   - Stop capture session

**Key Code:**
```swift
override func viewDidLoad() {
    super.viewDidLoad()

    // Create RoomPlan's capture view
    let captureView = RoomPlan.RoomCaptureView(frame: view.bounds)
    view.addSubview(captureView)

    // Layout constraints
    captureView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        captureView.topAnchor.constraint(equalTo: view.topAnchor),
        captureView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        captureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        captureView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])

    self.roomCaptureView = captureView

    // Create coordinator
    let coord = viewModel.createCoordinator(
        captureSession: captureView.captureSession
    )
    coordinator = coord

    // Set as delegate
    captureView.captureSession.delegate = coord
}
```

### RoomCaptureCoordinator

**Purpose:** Handle RoomPlan session delegate callbacks

**Implementation:**
```swift
@MainActor
final class RoomCaptureCoordinator: NSObject, RoomCaptureSessionDelegate {
    private let captureSession: RoomCaptureSession
    private let onUpdate: (CapturedRoom) -> Void
    private let onError: (Error) -> Void

    var arSession: ARSession {
        captureSession.arSession
    }

    func startCapture() {
        let configuration = RoomCaptureSession.Configuration()
        captureSession.run(configuration: configuration)
    }

    func stopCapture() {
        captureSession.stop()
    }

    // Delegate methods...
}
```

**Delegate Callbacks:**

```swift
// Called continuously as room updates
func captureSession(_ session: RoomCaptureSession,
                   didUpdate room: CapturedRoom) {
    onUpdate(room)  // → ViewModel.handleRoomUpdated()
}

// Called when session ends
func captureSession(_ session: RoomCaptureSession,
                   didEndWith data: CapturedRoomData,
                   error: Error?) {
    if let error = error {
        onError(error)  // → ViewModel.handleError()
    }
}

// Called when session starts
func captureSession(_ session: RoomCaptureSession,
                   didStartWith configuration: Configuration) {
    debugPrint("✅ Capture session started")
}
```

### RoomCaptureViewModel

**Purpose:** Business logic, state management, and service coordination

**Properties:**
```swift
// UI State
var isCapturing = false
var isSaving = false
var canExport = false
var isProcessingPhoto = false
var errorMessage: String?

// Data
var capturedRoom: CapturedRoom?
var capturedPhotos: [(image: UIImage, pose: SpatialPose)] = []

// Dependencies
private let persistenceService: any PersistenceProtocol
private let permissionsManager: any PermissionsProtocol
private var coordinator: RoomCaptureCoordinator?

// Callback
let onComplete: (RoomScan) -> Void
```

**Methods:**
- `checkPermissions()` - Verify camera/ARKit access
- `createCoordinator()` - Setup RoomPlan delegate
- `startCapture()` - Begin scanning
- `stopCapture()` - End scanning
- `capturePhoto()` - Take photo at current position
- `generateDefaultRoomName()` - Create "Room Scan X" name
- `finishCapture(withName:)` - Export and save
- `handleRoomUpdated()` - Process room updates
- `handleError()` - Handle scan errors

---

## Complete Workflow

### 1. View Initialization

```
DashboardView taps camera button
    ↓
showingScanner = true
    ↓
.fullScreenCover presents NavigationStack { RoomCaptureView }
    ↓
RoomCaptureView.init(onComplete: { scan in ... })
    ↓
Creates RoomCaptureViewModel(onComplete: callback)
    ↓
RoomCaptureView.body renders
    ↓
Creates RoomCaptureViewRepresentable(viewModel)
    ↓
RoomCaptureViewRepresentable.makeUIViewController()
    ↓
Creates RoomCaptureViewController(viewModel)
```

### 2. View Lifecycle

```
RoomCaptureViewController.viewDidLoad()
    ├─ Create RoomPlan.RoomCaptureView
    ├─ Add to view hierarchy
    ├─ Create RoomCaptureCoordinator
    └─ Set as session delegate

RoomCaptureViewController.viewDidAppear()
    ├─ Task { await viewModel.checkPermissions() }
    │   ├─ PermissionsManager.checkRoomScanRequirements()
    │   │   ├─ Check ARKit support
    │   │   ├─ Check LiDAR availability
    │   │   └─ Request camera permission
    │   └─ Return true/false
    ├─ If permissions granted:
    │   └─ viewModel.startCapture()
    │       └─ coordinator.startCapture()
    │           └─ session.run(configuration)
    └─ RoomPlan AR view starts showing camera
```

### 3. Active Scanning

```
User moves device around room
    ↓
RoomPlan detects surfaces, walls, doors, windows
    ↓
captureSession(_:didUpdate:) fires repeatedly
    ↓
Coordinator → onUpdate(room)
    ↓
ViewModel.handleRoomUpdated(room)
    ├─ capturedRoom = room
    └─ canExport = true

UI Updates:
    └─ "Finish" button appears (canExport = true)
```

### 4. Photo Capture

```
User taps "Take Photo" button
    ↓
RoomCaptureView calls: Task { await viewModel.capturePhoto() }
    ↓
ViewModel.capturePhoto() async
    ├─ isProcessingPhoto = true
    ├─ Get ARSession: coordinator.arSession
    ├─ Get current frame: arSession.currentFrame
    ├─ Extract camera transform (4x4 matrix)
    │   ├─ position = SIMD3(columns.3.x, .y, .z)
    │   └─ orientation = simd_quatf(transform)
    ├─ Create SpatialPose(position, orientation)
    ├─ Get pixel buffer: frame.capturedImage
    ├─ Convert to CIImage
    ├─ Rotate .right (portrait)
    ├─ Create CGImage
    ├─ Create UIImage(scale: 1.0, orientation: .up)
    ├─ Append (image, pose) to capturedPhotos
    └─ isProcessingPhoto = false

UI Updates:
    └─ Photo count increments: "5 photos"
```

### 5. Finish and Save

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
    ├─ coordinator.stopCapture()
    └─ Task { await saveCompletedScan(room, name) }
        ├─ isSaving = true
        ├─ UI shows: "Saving room scan..."
        │
        ├─ exportRoomToUSDZ(room) async
        │   ├─ Task.detached (background queue)
        │   ├─ room.export(to: tempURL)
        │   ├─ Read USDZ data
        │   ├─ Delete temp file
        │   └─ Return Data
        │
        ├─ persistenceService.saveCompletedScan(name, usdzData, photos)
        │   ├─ Create scan directory
        │   ├─ Write room.usdz
        │   ├─ Create photos directory
        │   ├─ Compress and write each photo
        │   └─ Write scan.json metadata
        │
        ├─ handleSaveSuccess(scan)
        │   ├─ isSaving = false
        │   ├─ isCapturing = false
        │   └─ onComplete(scan)
        │
        └─ onComplete callback fires
            ├─ DashboardView: showingScanner = false
            └─ DashboardView: viewModel.loadScans()

User returns to dashboard with new scan
```

---

## Photo Capture Implementation

### ARKit Frame Access

RoomPlan's `RoomCaptureSession` owns an `ARSession`:

```swift
let arSession = captureView.captureSession.arSession
```

### Current Frame Extraction

```swift
guard let frame = arSession.currentFrame else {
    errorMessage = "Camera frame not available"
    return
}
```

**ARFrame contains:**
- `camera` - Camera intrinsics and extrinsics
- `capturedImage` - Pixel buffer (CVPixelBuffer)
- `timestamp` - Capture time
- `anchors` - Detected ARAnchors
- `lightEstimate` - Lighting information

### Camera Transform (4x4 Matrix)

```swift
let transform = frame.camera.transform  // simd_float4x4
```

**Matrix structure:**
```
┌                           ┐
│ r00  r01  r02  position.x │
│ r10  r11  r12  position.y │
│ r20  r21  r22  position.z │
│  0    0    0       1      │
└                           ┘
```

### Position Extraction

```swift
let position = SIMD3<Float>(
    transform.columns.3.x,  // Right/left in meters
    transform.columns.3.y,  // Up/down in meters
    transform.columns.3.z   // Forward/back in meters
)
```

**Coordinate system:**
- +X = right
- +Y = up
- +Z = backward (toward user)

### Orientation Extraction (Quaternion)

```swift
let orientation = simd_quatf(transform)
```

**Quaternion components:**
```swift
orientation.real       // w (scalar)
orientation.imag.x     // x (i)
orientation.imag.y     // y (j)
orientation.imag.z     // z (k)
```

**Why quaternion?**
- No gimbal lock
- Efficient interpolation
- Standard in 3D graphics
- Compatible with ARKit/SceneKit

### Image Processing

```swift
// 1. Get pixel buffer
let pixelBuffer = frame.capturedImage  // CVPixelBuffer (YCbCr format)

// 2. Convert to CIImage
let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

// 3. Rotate for portrait
let rotated = ciImage.oriented(.right)  // 90° clockwise

// 4. Create context
let context = CIContext()

// 5. Render to CGImage
guard let cgImage = context.createCGImage(rotated, from: rotated.extent) else {
    throw NSError(domain: "RoomCapture", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Failed to convert image"
    ])
}

// 6. Create UIImage
let image = UIImage(
    cgImage: cgImage,
    scale: AppConfiguration.Image.defaultScale,  // 1.0
    orientation: .up
)
```

**Why .oriented(.right)?**
- ARKit captures in landscape orientation
- App runs in portrait
- .right = 90° clockwise rotation
- Results in correctly oriented portrait image

### In-Memory Storage

```swift
capturedPhotos.append((image: image, pose: cameraPose))
```

**Tuple structure:**
```swift
(
    image: UIImage,              // Full-resolution image in memory
    pose: SpatialPose(           // Where photo was taken
        position: SIMD3<Float>,
        orientation: simd_quatf
    )
)
```

**Memory impact:**
- ~1-2 MB per photo (uncompressed in memory)
- Typical scan: 5-10 photos = 10-20 MB
- Released after save completes

---

## USDZ Export Process

### Export on Background Queue

```swift
private func exportRoomToUSDZ(_ room: CapturedRoom) async throws -> Data {
    try await Task.detached {
        // Create temporary file
        let usdzURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).usdz")

        debugPrint("🏠 Exporting to USDZ: \(usdzURL.path)")

        // RoomPlan export (CPU-intensive, runs on background queue)
        try await room.export(to: usdzURL)

        // Verify file exists
        guard FileManager.default.fileExists(atPath: usdzURL.path) else {
            throw NSError(domain: "RoomCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Export succeeded but file not found"
            ])
        }

        // Read into memory
        let data = try Data(contentsOf: usdzURL)
        debugPrint("🏠 USDZ file size: \(data.count) bytes")

        // Clean up
        try? FileManager.default.removeItem(at: usdzURL)

        return data
    }.value  // Returns to MainActor context
}
```

**Why Task.detached?**
- `room.export(to:)` is CPU-intensive (mesh processing)
- Detached task runs on background thread pool
- `.value` awaits completion and returns to caller's context (MainActor)
- Prevents UI freeze during export

**File sizes:**
- Simple room: 1-2 MB
- Complex room: 3-5 MB
- Depends on geometry complexity

---

## State Management

### State Properties

```swift
// Capability flags
var isCapturing: Bool           // Session is running
var canExport: Bool             // Room data available

// Activity flags
var isSaving: Bool              // Export/save in progress
var isProcessingPhoto: Bool     // Photo capture in progress

// Error state
var errorMessage: String?       // Current error to display

// Data state
var capturedRoom: CapturedRoom? // Latest room data from RoomPlan
var capturedPhotos: [...]       // Photos captured this session
```

### State Transitions

```
┌─────────────┐
│ Initialized │ isCapturing=false, canExport=false
└──────┬──────┘
       │ checkPermissions() → startCapture()
       ↓
┌──────────┐
│ Scanning │ isCapturing=true, canExport=false
└─────┬────┘
      │ didUpdate room
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
     ├─ Success → onComplete()
     │
     └─ Failure → errorMessage set
```

### UI State Binding

```swift
// Finish button only shown when ready
if viewModel.canExport {
    Button("Finish") { /* ... */ }
        .disabled(viewModel.isSaving)
}

// Take Photo button only during scanning
if viewModel.isCapturing && !viewModel.isSaving {
    Button("Take Photo") { /* ... */ }
        .disabled(viewModel.isProcessingPhoto)
}

// Saving indicator
if viewModel.isSaving {
    ProgressView()
    Text("Saving room scan...")
}

// Error display
if let error = viewModel.errorMessage {
    Text(error)
        .foregroundColor(.red)
}
```

---

## Error Handling

### Permission Errors

```swift
func checkPermissions() async -> Bool {
    let result = await permissionsManager.checkRoomScanRequirements()

    if !result.isSuccess {
        errorMessage = result.errorMessage
        // Examples:
        // - "This device doesn't support ARKit"
        // - "This device doesn't have a LiDAR sensor..."
        // - "Camera access is required..."
        return false
    }

    return true
}
```

### Photo Capture Errors

```swift
func capturePhoto() async {
    do {
        // ... capture logic ...
    } catch {
        errorMessage = "Failed to capture photo: \(error.localizedDescription)"
        isProcessingPhoto = false
    }
}
```

### Save Errors

```swift
private func handleSaveError(_ error: Error) {
    debugPrint("🏠 [RoomCaptureVM] ❌ Save failed: \(error)")
    isSaving = false
    isCapturing = false
    errorMessage = "Failed to save scan: \(error.localizedDescription)"
}
```

**User experience:**
- Errors displayed as red text at bottom
- User can continue scanning after error
- Failed saves don't lose scan data (still in memory)
- User can retry with different name

---

## Testing

### Mock ViewModel

```swift
@MainActor
final class MockRoomCaptureViewModel: RoomCaptureViewModelProtocol {
    var isCapturing = false
    var canExport = false
    var isSaving = false
    var isProcessingPhoto = false
    var errorMessage: String?
    var capturedPhotos: [(UIImage, SpatialPose)] = []
    var onComplete: (RoomScan) -> Void

    init(onComplete: @escaping (RoomScan) -> Void = { _ in }) {
        self.onComplete = onComplete
    }

    func checkPermissions() async -> Bool { true }
    func startCapture() { isCapturing = true; canExport = true }
    func stopCapture() { isCapturing = false }

    func capturePhoto() async {
        let mockImage = UIImage()
        let mockPose = SpatialPose(
            position: SIMD3(0, 1.5, 0),
            orientation: simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
        )
        capturedPhotos.append((mockImage, mockPose))
    }

    func generateDefaultRoomName() -> String { "Mock Room 1" }

    func finishCapture(withName name: String) {
        let scan = RoomScan(/* ... */)
        onComplete(scan)
    }
}
```

### Test Cases

1. **Permission check flow**
2. **Capture start/stop**
3. **Photo capture**
4. **Room name generation**
5. **Save workflow**
6. **Error handling**

---

## Performance Considerations

### Memory Management

- Photos in memory: 10-20 MB typical
- USDZ export: Additional 5-10 MB peak
- Released after save
- No memory leaks (verified with Instruments)

### CPU Usage

- Photo capture: ~50ms on A14+ chips
- USDZ export: 1-3 seconds (background thread)
- Main thread never blocked

### Best Practices

- Use Task.detached for heavy operations
- Compress images before saving
- Clean up temp files immediately
- Batch writes to disk

---

## Future Enhancements

1. **Photo Thumbnails** - Show previews before saving
2. **Undo Photo** - Remove last captured photo
3. **Photo Editing** - Crop/rotate before save
4. **Surface Tagging** - Associate photos with detected walls
5. **Progress Indicator** - Show export percentage
6. **Auto-save** - Periodic background saves
