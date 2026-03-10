# Dashboard Module

## Overview

The Dashboard module displays a list of all saved room scans and serves as the main entry point for the application.

## Purpose

- Display list of completed room scans
- Allow users to create new scans
- Delete existing scans
- Navigate to scan viewer
- Sort scans by capture date

## Architecture

```
DashboardView (SwiftUI)
    ↓
DashboardViewModel (Business Logic)
    ↓
PersistenceService (Data Access)
```

## Files

- **DashboardView.swift** - SwiftUI view presenting scan list
- **DashboardViewModel.swift** - Business logic and state management
- **DashboardViewModelProtocol.swift** - Protocol defining public interface

---

## DashboardView Implementation

### Component Structure

```swift
DashboardView
├── NavigationStack
│   ├── Loading State → ProgressView
│   ├── Empty State → emptyStateView
│   └── Scan List → scanListView
│       └── For each scan: ScanRow
├── Toolbar
│   └── Camera Button → Start new scan
├── Error Alert
└── Full Screen Covers
    ├── RoomCaptureView (scanner)
    └── RoomViewerView (viewer)
```

### State Properties

```swift
@State private var viewModel = DashboardViewModel()
@State private var selectedScan: RoomScan?
@State private var showingViewer = false
@State private var showingScanner = false
```

### View States

**1. Loading State**
```swift
if viewModel.isLoading {
    ProgressView("Loading scans...")
}
```

**2. Empty State**
```swift
VStack {
    Image(systemName: "camera.metering.center.weighted")
        .font(.system(size: 80))
    Text("No Room Scans")
    Text("Scan a room to create a 3D model...")
    Button("Scan Your First Room") {
        startNewScan()
    }
}
```

**3. Scan List**
```swift
List {
    ForEach(viewModel.scans) { scan in
        ScanRow(scan: scan)
            .onTapGesture {
                selectedScan = scan
                showingViewer = true
            }
    }
    .onDelete { indexSet in
        for index in indexSet {
            viewModel.deleteScan(viewModel.scans[index])
        }
    }
}
```

### ScanRow Component

Displays individual scan with:
- Cube icon (placeholder for future thumbnail)
- Scan name
- Photo count with icon
- Capture date
- Chevron right indicator

```swift
struct ScanRow: View {
    let scan: RoomScan

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "cube.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(scan.name)
                    .font(.system(size: 16, weight: .semibold))

                HStack {
                    Image(systemName: "photo.fill")
                    Text("\(scan.photos.count) photos")
                }
                .foregroundStyle(.green)

                Text(scan.captureDate.formatted(...))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
        }
    }
}
```

### Navigation

**To Scanner:**
```swift
.fullScreenCover(isPresented: $showingScanner) {
    NavigationStack {
        RoomCaptureView { scan in
            showingScanner = false
            viewModel.loadScans()  // Refresh list
        }
    }
}
```

**To Viewer:**
```swift
.navigationDestination(isPresented: $showingViewer) {
    if let scan = selectedScan {
        RoomViewerView(scan: scan)
    }
}
```

---

## DashboardViewModel Implementation

### Properties

```swift
var scans: [RoomScan] = []        // All saved scans
var isLoading = false              // Loading indicator
var errorMessage: String?          // Error to display

private let persistenceService: any PersistenceProtocol
```

### Initialization

```swift
init(persistenceService: any PersistenceProtocol = PersistenceService.shared) {
    self.persistenceService = persistenceService
    // Don't load here - let view trigger with .task
}
```

**Why defer loading?**
- View controls when data loads (via `.task` modifier)
- Prevents loading before view appears
- Allows proper loading state display

### Load Scans

```swift
func loadScans() {
    debugPrint("📋 [DashboardVM] Loading scans...")
    isLoading = true
    errorMessage = nil

    do {
        scans = try persistenceService.loadAllScans()
        scans.sort { $0.captureDate > $1.captureDate }
        debugPrint("📋 [DashboardVM] ✅ Loaded \(scans.count) scans")
    } catch {
        debugPrint("📋 [DashboardVM] ❌ Failed: \(error.localizedDescription)")
        errorMessage = "Failed to load scans: \(error.localizedDescription)"
    }

    isLoading = false
}
```

**Sort order:** Most recent first (descending by captureDate)

### Delete Scan

```swift
func deleteScan(_ scan: RoomScan) {
    debugPrint("📋 [DashboardVM] Deleting scan: \(scan.name)")

    do {
        try persistenceService.deleteScan(scan)
        scans.removeAll { $0.id == scan.id }
        debugPrint("📋 [DashboardVM] ✅ Scan deleted successfully")
    } catch {
        debugPrint("📋 [DashboardVM] ❌ Failed: \(error.localizedDescription)")
        errorMessage = "Failed to delete scan: \(error.localizedDescription)"
    }
}
```

**Two-step process:**
1. Delete from file system via PersistenceService
2. Remove from in-memory array (triggers UI update)

### Format Display Date

```swift
func scanDisplayDate(_ scan: RoomScan) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(
        for: scan.captureDate,
        relativeTo: Date()
    )
}
```

**Examples:**
- "2 hours ago"
- "Yesterday"
- "Last week"

---

## Data Flow

### App Launch Flow

```
App Launch
    ↓
ContentView = DashboardView()
    ↓
DashboardView.body
    ↓
.task { viewModel.loadScans() }
    ↓
PersistenceService.loadAllScans()
    ├─ Find all scan directories
    ├─ For each: Load scan.json
    ├─ Decode RoomScan models
    └─ Update file paths
    ↓
Sort by date (newest first)
    ↓
Update scans property
    ↓
SwiftUI re-renders list
```

### Create New Scan Flow

```
User taps camera button
    ↓
showingScanner = true
    ↓
.fullScreenCover presents RoomCaptureView
    ↓
User completes scan
    ↓
onComplete callback fires
    ↓
showingScanner = false (dismiss)
    ↓
viewModel.loadScans() (refresh)
    ↓
New scan appears in list
```

### View Scan Flow

```
User taps ScanRow
    ↓
selectedScan = scan
showingViewer = true
    ↓
.navigationDestination pushes RoomViewerView(scan)
    ↓
User views 3D model
    ↓
User taps back button
    ↓
Returns to dashboard
```

### Delete Scan Flow

```
User swipes row left
    ↓
System shows delete button
    ↓
User taps delete
    ↓
.onDelete fires with IndexSet
    ↓
viewModel.deleteScan(scan)
    ↓
PersistenceService deletes directory
    ↓
Remove from scans array
    ↓
SwiftUI animates row removal
```

---

## State Management

### ViewModel States

```
┌─────────┐
│ Initial │ isLoading=false, scans=[], errorMessage=nil
└────┬────┘
     │ .task { loadScans() }
     ↓
┌─────────┐
│ Loading │ isLoading=true, scans=[], errorMessage=nil
└────┬────┘
     │
     ├─ Success
     │    ↓
     │  ┌────────┐
     │  │ Loaded │ isLoading=false, scans=[...], errorMessage=nil
     │  └────────┘
     │
     └─ Failure
          ↓
        ┌───────┐
        │ Error │ isLoading=false, scans=[], errorMessage="..."
        └───────┘
```

### View Rendering Logic

```swift
if viewModel.isLoading {
    // Show progress spinner
} else if viewModel.scans.isEmpty {
    // Show empty state
} else {
    // Show scan list
}
```

**Error Display:**
- Separate alert triggered by errorMessage != nil
- User acknowledges, errorMessage set to nil
- View returns to appropriate state (empty or loaded)

---

## Error Handling

### Possible Errors

1. **File System Errors**
   - Directory doesn't exist (first launch)
   - Permission denied
   - Disk full
   - Corrupted JSON

2. **Decoding Errors**
   - Invalid JSON format
   - Missing required fields
   - Type mismatch

### Error Recovery

**Load Errors:**
```swift
catch {
    errorMessage = "Failed to load scans: \(error.localizedDescription)"
    scans = []  // Empty list (graceful degradation)
}
```

**Delete Errors:**
```swift
catch {
    errorMessage = "Failed to delete scan: \(error.localizedDescription)"
    // Scan remains in list (safe - no partial delete)
}
```

### User Experience

- Loading state prevents interaction during I/O
- Error alerts explain what went wrong
- Failed deletes don't corrupt list
- Refresh available via pull-to-refresh

---

## Testing

### Mock ViewModel

```swift
@MainActor
final class MockDashboardViewModel: DashboardViewModelProtocol {
    var scans: [RoomScan] = []
    var isLoading = false
    var errorMessage: String?

    func loadScans() {
        scans = [
            RoomScan(
                name: "Test Room",
                usdURL: URL(fileURLWithPath: "/tmp/test.usdz"),
                captureDate: Date(),
                photos: [],
                directory: URL(fileURLWithPath: "/tmp")
            )
        ]
    }

    func deleteScan(_ scan: RoomScan) {
        scans.removeAll { $0.id == scan.id }
    }

    func scanDisplayDate(_ scan: RoomScan) -> String {
        return "2 days ago"
    }
}
```

### Test Cases

1. **Load empty scans** - Verify empty state shown
2. **Load with scans** - Verify list displayed
3. **Delete scan** - Verify removed from list
4. **Load error** - Verify error message shown
5. **Delete error** - Verify scan remains in list

### SwiftUI Previews

```swift
#Preview("Empty State") {
    DashboardView()
}

#Preview("With Scans") {
    NavigationStack {
        List {
            ForEach(makeSampleScans()) { scan in
                ScanRow(scan: scan)
            }
        }
    }
}
```

---

## Performance

### Optimization Techniques

1. **Lazy Loading**
   - Only decode JSON when scanning directory
   - Path updates done in-place (mutating)
   - SceneKit models NOT loaded until viewer opens

2. **Efficient Sorting**
   - Single sort after loading (O(n log n))
   - Not re-sorted on every update

3. **SwiftUI Optimizations**
   - List identity via `Identifiable` (UUID)
   - Minimal view updates (only changed scans)
   - Lazy rendering of off-screen rows

### Memory Footprint

- **Per Scan:** ~500 bytes (model only, no images)
- **100 Scans:** ~50 KB total in memory
- **List Rendering:** Only visible rows kept in memory

---

## Future Enhancements

### Planned Features

1. **Thumbnail Generation**
   - Render USDZ preview
   - Cache as image
   - Display in ScanRow

2. **Search/Filter**
   - Search by name
   - Filter by date range
   - Sort options (name, date, size)

3. **Bulk Operations**
   - Multi-select
   - Batch delete
   - Export multiple scans

4. **Metadata Display**
   - Room dimensions
   - File size
   - Number of surfaces detected

### Extension Points

- `DashboardViewModelProtocol` allows alternative implementations
- `PersistenceProtocol` enables cloud storage
- ScanRow can be enhanced without changing ViewModel
