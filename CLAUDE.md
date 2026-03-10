# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RoomPlan is an iOS/multiplatform SwiftUI application built with Xcode that utilizes Apple's RoomPlan framework for room scanning capabilities.

## Build and Test Commands

### Building the Project
```bash
# Build the main app from command line
xcodebuild -project RoomPlan/RoomPlan.xcodeproj -scheme RoomPlan -configuration Debug build

# Build for specific platform (iOS, macOS, or visionOS)
xcodebuild -project RoomPlan/RoomPlan.xcodeproj -scheme RoomPlan -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project RoomPlan/RoomPlan.xcodeproj -scheme RoomPlan -sdk macosx build
xcodebuild -project RoomPlan/RoomPlan.xcodeproj -scheme RoomPlan -sdk xrsimulator build
```

### Running Tests
```bash
# Run all unit tests
xcodebuild test -project RoomPlan/RoomPlan.xcodeproj -scheme RoomPlan -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run specific test class
xcodebuild test -project RoomPlan/RoomPlan.xcodeproj -scheme RoomPlan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoomPlanTests/RoomPlanTests

# Run UI tests
xcodebuild test -project RoomPlan/RoomPlan.xcodeproj -scheme RoomPlan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoomPlanUITests
```

### Opening in Xcode
```bash
open RoomPlan/RoomPlan.xcodeproj
```

## Project Structure

The project follows a module-based architecture:

- **App/**: Contains the main app entry point (`RoomPlanApp.swift`)
- **Modules/**: Contains SwiftUI views and features (currently just `ContentView.swift`)
- **Resources/**: Contains asset catalogs (icons, colors, images)
- **RoomPlanTests/**: Unit test target
- **RoomPlanUITests/**: UI test target

The Xcode project is located at `RoomPlan/RoomPlan.xcodeproj` (note the nested directory structure).

## Platform Support

This is a multi-platform app targeting:
- iOS 26.1+
- macOS 26.1+
- visionOS 26.1+

The deployment targets are configured in the Xcode project with `SDKROOT = auto` and supported platforms set to `iphoneos iphonesimulator macosx xros xrsimulator`.

## Swift Configuration

- Swift 6
- Strict concurrency enabled (`SWIFT_APPROACHABLE_CONCURRENCY = YES`)
- Default actor isolation set to MainActor (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- SwiftUI previews enabled

## Key Technical Details

- Bundle ID: `com.arnlee.RoomPlan`
- Development Team: 98Y77AF9SU
- App Sandbox enabled with read-only user-selected files access
- Hardened runtime enabled for macOS
- Supported device families: iPhone, iPad, and Apple Vision Pro

## Notes

- The Xcode project currently uses Swift 5.0 but should be updated to Swift 6 in the build settings
