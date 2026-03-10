//
//  PermissionsProtocol.swift
//  RoomPlanApp
//
//  Protocol for checking app permissions and capabilities
//

import Foundation
import AVFoundation
import ARKit

// MARK: - Supporting Types

enum PermissionStatus {
    case authorized
    case denied
}

enum RequirementCheckResult {
    case success
    case failure(message: String)

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Protocol

/// Protocol for checking permissions and device capabilities
protocol PermissionsProtocol: Sendable {
    /// Check if camera access is authorized
    var isCameraAuthorized: Bool { get }

    /// Check if device supports ARKit
    var isARKitSupported: Bool { get }

    /// Check if device has LiDAR sensor
    var hasLiDARSupport: Bool { get }

    /// Request camera permission
    func requestCameraPermission() async -> Bool

    /// Get camera authorization status
    func checkCameraPermission() async -> PermissionStatus

    /// Check all required permissions and capabilities for room scanning
    func checkRoomScanRequirements() async -> RequirementCheckResult

    /// Check requirements for panorama capture (doesn't need LiDAR)
    func checkPanoramaCaptureRequirements() async -> RequirementCheckResult
}

// MARK: - Make PermissionsManager conform to protocol
extension PermissionsManager: PermissionsProtocol {}
