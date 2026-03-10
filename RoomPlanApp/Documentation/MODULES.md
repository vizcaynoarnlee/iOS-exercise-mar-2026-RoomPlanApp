# Module Documentation Index

## Overview

Each module has its own detailed documentation in its `Documentation/` folder.

---

## Dashboard Module

**Location:** `RoomPlanApp/Modules/Dashboard/Documentation/`

**Purpose:** Main screen displaying list of saved room scans

**Key Components:**
- DashboardView - SwiftUI scan list
- DashboardViewModel - Load/delete operations
- ScanRow - Individual scan display component

**Documentation Sections:**
- View implementation details
- ViewModel architecture
- Data flow diagrams
- State management
- Error handling
- Testing guide

**Read Full Documentation:** [Dashboard/Documentation/DASHBOARD_IMPLEMENTATION.md](../RoomPlanApp/Modules/Dashboard/Documentation/DASHBOARD_IMPLEMENTATION.md)

---

## RoomCapture Module

**Location:** `RoomPlanApp/Modules/RoomCapture/Documentation/`

**Purpose:** Complete room scanning workflow with RoomPlan and photo capture

**Key Components:**
- RoomCaptureView - SwiftUI overlay UI
- RoomCaptureViewRepresentable - UIKit bridge
- RoomCaptureViewController - RoomPlan container
- RoomCaptureViewModel - Business logic
- RoomCaptureCoordinator - RoomPlan delegate

**Documentation Sections:**
- Complete workflow walkthrough
- RoomPlan integration details
- ARKit photo capture system
- Camera pose extraction (quaternions)
- Image processing pipeline
- USDZ export process
- State management
- Error handling
- Testing guide
- Performance considerations

**Read Full Documentation:** [RoomCapture/Documentation/ROOMCAPTURE_IMPLEMENTATION.md](../RoomPlanApp/Modules/RoomCapture/Documentation/ROOMCAPTURE_IMPLEMENTATION.md)

---

## Viewer Module

**Location:** `RoomPlanApp/Modules/Viewer/Documentation/`

**Purpose:** Display completed room scans in 3D with SceneKit

**Key Components:**
- RoomViewerView - SwiftUI + SceneKit integration
- RoomViewerViewModel - Minimal state management
- SceneKit scene graph

**Documentation Sections:**
- SceneKit integration
- USDZ model loading
- Camera setup and controls
- Photo debug markers
- Coordinate system mapping
- Rendering pipeline
- Performance metrics
- Future enhancements

**Read Full Documentation:** [Viewer/Documentation/VIEWER_IMPLEMENTATION.md](../RoomPlanApp/Modules/Viewer/Documentation/VIEWER_IMPLEMENTATION.md)

---

## Documentation Structure

```
RoomPlanApp/
└── Modules/
    ├── Dashboard/
    │   ├── Documentation/
    │   │   └── DASHBOARD_IMPLEMENTATION.md      ← Dashboard implementation details
    │   ├── DashboardView.swift
    │   ├── DashboardViewModel.swift
    │   └── DashboardViewModelProtocol.swift
    │
    ├── RoomCapture/
    │   ├── Documentation/
    │   │   └── ROOMCAPTURE_IMPLEMENTATION.md    ← RoomCapture implementation details
    │   ├── RoomCaptureView.swift
    │   ├── RoomCaptureViewModel.swift
    │   ├── RoomCaptureViewRepresentable.swift
    │   ├── RoomCaptureCoordinator.swift
    │   └── RoomCaptureViewModelProtocol.swift
    │
    └── Viewer/
        ├── Documentation/
        │   └── VIEWER_IMPLEMENTATION.md         ← Viewer implementation details
        ├── RoomViewerView.swift
        ├── RoomViewerViewModel.swift
        └── RoomViewerViewModelProtocol.swift
```

---

## Quick Navigation

### By Topic

**UI Implementation:**
- [Dashboard UI](../RoomPlanApp/Modules/Dashboard/Documentation/DASHBOARD_IMPLEMENTATION.md#dashboardview-implementation)
- [RoomCapture UI](../RoomPlanApp/Modules/RoomCapture/Documentation/ROOMCAPTURE_IMPLEMENTATION.md#file-responsibilities)
- [Viewer UI](../RoomPlanApp/Modules/Viewer/Documentation/VIEWER_IMPLEMENTATION.md#roomviewerview-implementation)

**Business Logic:**
- [Dashboard ViewModel](../RoomPlanApp/Modules/Dashboard/Documentation/DASHBOARD_IMPLEMENTATION.md#dashboardviewmodel-implementation)
- [RoomCapture ViewModel](../RoomPlanApp/Modules/RoomCapture/Documentation/ROOMCAPTURE_IMPLEMENTATION.md#roomcaptureviewmodel)
- [Viewer ViewModel](../RoomPlanApp/Modules/Viewer/Documentation/VIEWER_IMPLEMENTATION.md#roomviewerviewmodel-implementation)

**Data Flow:**
- [Dashboard Flow](../RoomPlanApp/Modules/Dashboard/Documentation/DASHBOARD_IMPLEMENTATION.md#data-flow)
- [RoomCapture Workflow](../RoomPlanApp/Modules/RoomCapture/Documentation/ROOMCAPTURE_IMPLEMENTATION.md#complete-workflow)
- [Viewer Flow](../RoomPlanApp/Modules/Viewer/Documentation/VIEWER_IMPLEMENTATION.md#data-flow)

**Testing:**
- [Dashboard Testing](../RoomPlanApp/Modules/Dashboard/Documentation/DASHBOARD_IMPLEMENTATION.md#testing)
- [RoomCapture Testing](../RoomPlanApp/Modules/RoomCapture/Documentation/ROOMCAPTURE_IMPLEMENTATION.md#testing)
- [Viewer Testing](../RoomPlanApp/Modules/Viewer/Documentation/VIEWER_IMPLEMENTATION.md#testing)

---

## Contributing to Documentation

### Adding New Modules

When creating a new module:

1. Create `ModuleName/Documentation/` folder
2. Add `MODULENAME_IMPLEMENTATION.md` with:
   - Overview and purpose
   - Architecture diagram
   - File responsibilities
   - Implementation details
   - Data flow
   - State management
   - Error handling
   - Testing guide
   - Future enhancements

3. Update this index with link to new module

**Note:** Use uppercase module name prefix to ensure unique filenames (e.g., `DASHBOARD_IMPLEMENTATION.md`, `ROOMCAPTURE_IMPLEMENTATION.md`)

### Documentation Standards

- Use clear headings and structure
- Include code examples for complex concepts
- Add diagrams for data flow
- Document all public APIs
- Explain "why" not just "what"
- Keep examples concise and relevant
- Use consistent formatting

---

## Additional Resources

- [Overall Architecture](ARCHITECTURE.md) - System-wide architecture
- [Testing Guide](TESTING_GUIDE.md) - Testing strategies
- [Code Quality](CODE_QUALITY.md) - Standards and best practices
- [Implementation Details](IMPLEMENTATION.md) - Low-level implementation
