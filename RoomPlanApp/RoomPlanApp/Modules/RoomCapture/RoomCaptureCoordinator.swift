//
//  RoomCaptureCoordinator.swift
//  RoomPlan
//
//  Created by Arnlee Vizcayno on 3/8/26.
//

import Foundation
import RoomPlan
import ARKit

/// Coordinator that manages RoomPlan SDK integration and delegates to the view model
@MainActor
final class RoomCaptureCoordinator: NSObject, RoomCaptureSessionDelegate {
    private let captureSession: RoomCaptureSession
    private let onUpdate: (CapturedRoom) -> Void
    private let onError: (Error) -> Void

    /// Access to the underlying ARSession for panorama capture later
    var arSession: ARSession {
        captureSession.arSession
    }

    init(
        captureSession: RoomCaptureSession,
        onUpdate: @escaping (CapturedRoom) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.captureSession = captureSession
        self.onUpdate = onUpdate
        self.onError = onError
        super.init()
        debugPrint("🎯 [RoomCaptureCoordinator] Initialized with existing session")
    }

    func startCapture() {
        debugPrint("🎯 [RoomCaptureCoordinator] Starting RoomPlan capture session...")
        let configuration = RoomCaptureSession.Configuration()
        captureSession.run(configuration: configuration)
    }

    func stopCapture() {
        debugPrint("🎯 [RoomCaptureCoordinator] Stopping capture session")
        captureSession.stop()
    }

    // MARK: - RoomCaptureSessionDelegate

    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        debugPrint("🎯 [RoomCaptureCoordinator] Room data updated")
        // This is called continuously as the room is scanned
        // Pass the updated room to the view model
        onUpdate(room)
    }

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error = error {
            debugPrint("🎯 [RoomCaptureCoordinator] ❌ Session ended with error: \(error.localizedDescription)")
            onError(error)
        } else {
            debugPrint("🎯 [RoomCaptureCoordinator] Session ended successfully")
        }
    }

    // MARK: - Unused Delegate Methods (Protocol Requirements)

    func captureSession(_ session: RoomCaptureSession, didAdd room: CapturedRoom) {
        debugPrint("🎯 [RoomCaptureCoordinator] Room detected and added during scan")
    }

    func captureSession(_ session: RoomCaptureSession, didChange room: CapturedRoom) {
        debugPrint("🎯 [RoomCaptureCoordinator] Room data changed")
    }

    func captureSession(_ session: RoomCaptureSession, didRemove room: CapturedRoom) {
        debugPrint("🎯 [RoomCaptureCoordinator] Room data removed")
    }

    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        debugPrint("🎯 [RoomCaptureCoordinator] Instruction provided: \(instruction)")
    }

    func captureSession(_ session: RoomCaptureSession, didStartWith configuration: RoomCaptureSession.Configuration) {
        debugPrint("🎯 [RoomCaptureCoordinator] ✅ Capture session started")
    }
}

