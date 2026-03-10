//
//  RoomCaptureViewModelProtocol.swift
//  RoomPlanApp
//
//  Protocol defining the public interface for RoomCapture ViewModel
//

import Foundation
import RoomPlan
import UIKit

/// Protocol for RoomCapture ViewModel
/// Manages room scanning workflow with photo capture
@MainActor
protocol RoomCaptureViewModelProtocol: AnyObject, Observable {
    /// Whether room capture is currently active
    var isCapturing: Bool { get }

    /// Error message to display to user
    var errorMessage: String? { get set }

    /// Whether scan is being saved
    var isSaving: Bool { get }

    /// Whether scan is ready to be exported
    var canExport: Bool { get }

    /// Whether a photo is currently being processed
    var isProcessingPhoto: Bool { get }

    /// Photos captured during this scan session
    var capturedPhotos: [(image: UIImage, pose: SpatialPose)] { get }

    /// Completion handler called when scan is saved
    var onComplete: (RoomScan) -> Void { get }

    /// Check required permissions before starting
    func checkPermissions() async -> Bool

    /// Create coordinator for RoomPlan integration
    func createCoordinator(captureSession: RoomCaptureSession) -> RoomCaptureCoordinator

    /// Start room capture session
    func startCapture()

    /// Stop room capture session
    func stopCapture()

    /// Capture a photo at current camera position
    func capturePhoto() async

    /// Generate default name for new room scan
    func generateDefaultRoomName() -> String

    /// Finish capture and save with given name
    func finishCapture(withName name: String)
}
