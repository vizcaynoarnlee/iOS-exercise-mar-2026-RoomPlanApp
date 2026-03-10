//
//  PermissionsManager.swift
//  RoomPlanApp
//
//  Created by Arnlee Vizcayno on 3/8/26.
//

import Foundation
import AVFoundation
import ARKit

final class PermissionsManager {
    static let shared = PermissionsManager()

    private init() {}

    // MARK: - Camera Permissions

    /// Check if camera access is authorized
    var isCameraAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        debugPrint("🔐 [PermissionsManager] Requesting camera permission...")
        let result = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                debugPrint("🔐 [PermissionsManager] Camera permission \(granted ? "granted ✅" : "denied ❌")")
                continuation.resume(returning: granted)
            }
        }
        return result
    }

    /// Get camera authorization status
    func checkCameraPermission() async -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        debugPrint("🔐 [PermissionsManager] Camera authorization status: \(status.rawValue)")

        switch status {
        case .authorized:
            debugPrint("🔐 [PermissionsManager] Camera already authorized ✅")
            return .authorized
        case .denied, .restricted:
            debugPrint("🔐 [PermissionsManager] Camera denied/restricted ❌")
            return .denied
        case .notDetermined:
            debugPrint("🔐 [PermissionsManager] Camera permission not determined, requesting...")
            let granted = await requestCameraPermission()
            return granted ? .authorized : .denied
        @unknown default:
            debugPrint("🔐 [PermissionsManager] Unknown camera permission status ❌")
            return .denied
        }
    }

    // MARK: - ARKit Support

    /// Check if device supports ARKit
    var isARKitSupported: Bool {
        ARWorldTrackingConfiguration.isSupported
    }

    /// Check if device has LiDAR sensor (required for RoomPlan)
    var hasLiDARSupport: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    // MARK: - Combined Check

    /// Check all required permissions and capabilities for room scanning
    func checkRoomScanRequirements() async -> RequirementCheckResult {
        debugPrint("🔍 [PermissionsManager] Checking room scan requirements...")

        // Check ARKit support
        debugPrint("🔍 [PermissionsManager] ARKit supported: \(isARKitSupported)")
        guard isARKitSupported else {
            debugPrint("❌ [PermissionsManager] ARKit not supported on this device")
            return .failure(message: "This device doesn't support ARKit")
        }

        // Check LiDAR support
        debugPrint("🔍 [PermissionsManager] LiDAR supported: \(hasLiDARSupport)")
        guard hasLiDARSupport else {
            debugPrint("❌ [PermissionsManager] LiDAR not available on this device")
            return .failure(message: "This device doesn't have a LiDAR sensor. Room scanning requires iPhone 12 Pro or later, or iPad Pro (2020 or later).")
        }

        // Check camera permission
        let cameraStatus = await checkCameraPermission()
        guard cameraStatus == .authorized else {
            debugPrint("❌ [PermissionsManager] Camera permission not granted")
            return .failure(message: "Camera access is required. Please enable it in Settings.")
        }

        debugPrint("✅ [PermissionsManager] All room scan requirements met")
        return .success
    }

    /// Check requirements for panorama capture (doesn't need LiDAR)
    func checkPanoramaCaptureRequirements() async -> RequirementCheckResult {
        debugPrint("📸 [PermissionsManager] Checking panorama capture requirements...")

        // Check ARKit support
        debugPrint("📸 [PermissionsManager] ARKit supported: \(isARKitSupported)")
        guard isARKitSupported else {
            debugPrint("❌ [PermissionsManager] ARKit not supported on this device")
            return .failure(message: "This device doesn't support ARKit")
        }

        // Check camera permission
        let cameraStatus = await checkCameraPermission()
        guard cameraStatus == .authorized else {
            debugPrint("❌ [PermissionsManager] Camera permission not granted")
            return .failure(message: "Camera access is required. Please enable it in Settings.")
        }

        debugPrint("✅ [PermissionsManager] All panorama capture requirements met")
        return .success
    }
}

// Supporting types are now defined in PermissionsProviding.swift
