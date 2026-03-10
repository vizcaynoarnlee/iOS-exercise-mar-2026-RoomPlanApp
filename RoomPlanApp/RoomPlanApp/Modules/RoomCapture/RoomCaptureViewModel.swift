//
//  RoomCaptureViewModel.swift
//  RoomPlanApp
//
//  View model for room scanning with photo capture
//

import Foundation
import RoomPlan
import ARKit
import Observation
import UIKit

@MainActor
@Observable
final class RoomCaptureViewModel: RoomCaptureViewModelProtocol {
    var isCapturing = false
    var errorMessage: String?
    var capturedRoom: CapturedRoom?
    var isSaving = false
    var canExport = false
    var isProcessingPhoto = false

    // Photos with images stored in memory until scan completes
    var capturedPhotos: [(image: UIImage, pose: SpatialPose)] = []

    private let persistenceService: any PersistenceProtocol
    private let permissionsManager: any PermissionsProtocol
    private var coordinator: RoomCaptureCoordinator?

    let onComplete: (RoomScan) -> Void

    init(
        onComplete: @escaping (RoomScan) -> Void,
        persistenceService: any PersistenceProtocol = PersistenceService.shared,
        permissionsManager: any PermissionsProtocol = PermissionsManager.shared
    ) {
        self.onComplete = onComplete
        self.persistenceService = persistenceService
        self.permissionsManager = permissionsManager
        debugPrint("🏠 [RoomCaptureVM] Initialized for new scan")
    }

    /// Check permissions before starting capture
    func checkPermissions() async -> Bool {
        debugPrint("🏠 [RoomCaptureVM] Checking permissions...")
        let result = await permissionsManager.checkRoomScanRequirements()

        if !result.isSuccess {
            debugPrint("🏠 [RoomCaptureVM] ❌ Permission check failed")
            errorMessage = result.errorMessage
            return false
        }

        debugPrint("🏠 [RoomCaptureVM] ✅ Permissions granted")
        return true
    }

    func createCoordinator(captureSession: RoomCaptureSession) -> RoomCaptureCoordinator {
        let coordinator = RoomCaptureCoordinator(
            captureSession: captureSession,
            onUpdate: { [weak self] room in
                Task { @MainActor in
                    self?.handleRoomUpdated(room)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.handleError(error)
                }
            }
        )
        self.coordinator = coordinator
        return coordinator
    }

    func startCapture() {
        debugPrint("🏠 [RoomCaptureVM] Starting room capture...")
        isCapturing = true
        errorMessage = nil
        coordinator?.startCapture()
    }

    func stopCapture() {
        debugPrint("🏠 [RoomCaptureVM] Stopping capture session...")
        coordinator?.stopCapture()
        isCapturing = false
    }

    /// Capture a photo during room scanning
    func capturePhoto() async {
        guard let arSession = arSession else {
            debugPrint("🏠 [RoomCaptureVM] ❌ No AR session available")
            errorMessage = "AR session not available"
            return
        }

        guard let frame = arSession.currentFrame else {
            debugPrint("🏠 [RoomCaptureVM] ❌ No current frame available")
            errorMessage = "Camera frame not available"
            return
        }

        isProcessingPhoto = true
        errorMessage = nil

        do {
            debugPrint("📸 [RoomCaptureVM] Capturing photo during scan...")

            // Get camera transform
            let transform = frame.camera.transform
            let position = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            let orientation = simd_quatf(transform)

            let cameraPose = SpatialPose(
                position: position,
                orientation: orientation
            )

            // Capture image
            let pixelBuffer = frame.capturedImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

            // Rotate image to portrait orientation
            let rotated = ciImage.oriented(.right)

            let context = CIContext()
            guard let cgImage = context.createCGImage(rotated, from: rotated.extent) else {
                throw NSError(domain: "RoomCapture", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to convert image"
                ])
            }

            let image = UIImage(
                cgImage: cgImage,
                scale: AppConfiguration.Image.defaultScale,
                orientation: .up
            )

            // Store in memory (will be saved when scan completes)
            capturedPhotos.append((image: image, pose: cameraPose))

            debugPrint("📸 [RoomCaptureVM] ✅ Photo captured! Total: \(capturedPhotos.count)")
            isProcessingPhoto = false
        } catch {
            debugPrint("📸 [RoomCaptureVM] ❌ Photo capture failed: \(error)")
            errorMessage = "Failed to capture photo: \(error.localizedDescription)"
            isProcessingPhoto = false
        }
    }

    /// Generate default room name based on existing scans count
    func generateDefaultRoomName() -> String {
        let count = (try? persistenceService.loadAllScans().count) ?? 0
        return "\(AppConfiguration.Naming.defaultRoomNamePrefix) \(count + 1)"
    }

    func finishCapture(withName name: String) {
        debugPrint("🏠 [RoomCaptureVM] User finished capture with name: \(name)")
        coordinator?.stopCapture()

        // Export the captured room
        guard let room = capturedRoom else {
            debugPrint("🏠 [RoomCaptureVM] ❌ No room data to save")
            errorMessage = "No room data captured"
            isCapturing = false
            return
        }

        Task {
            await saveCompletedScan(room, withName: name)
        }
    }

    private func handleRoomUpdated(_ room: CapturedRoom) {
        // Store the latest room as it's being scanned
        capturedRoom = room
        canExport = true
        debugPrint("🏠 [RoomCaptureVM] Room data updated (can export: \(canExport))")
    }

    private func handleError(_ error: Error) {
        debugPrint("🏠 [RoomCaptureVM] ❌ Capture error: \(error.localizedDescription)")
        isCapturing = false
        errorMessage = "Capture failed: \(error.localizedDescription)"
    }

    private func saveCompletedScan(_ room: CapturedRoom, withName name: String) async {
        debugPrint("🏠 [RoomCaptureVM] Saving completed scan with name: \(name)")
        isSaving = true
        errorMessage = nil

        do {
            let usdzData = try await exportRoomToUSDZ(room)
            let scan = try persistenceService.saveCompletedScan(
                name: name,
                usdzData: usdzData,
                photos: capturedPhotos
            )
            handleSaveSuccess(scan)
        } catch {
            handleSaveError(error)
        }
    }

    /// Export room to USDZ format on background queue
    private func exportRoomToUSDZ(_ room: CapturedRoom) async throws -> Data {
        try await Task.detached {
            let usdzURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).usdz")

            debugPrint("🏠 [RoomCaptureVM] Exporting to USDZ: \(usdzURL.path)")

            // Export - this runs on background queue
            try await room.export(to: usdzURL)
            debugPrint("🏠 [RoomCaptureVM] ✅ Export completed")

            // Verify and read file
            guard FileManager.default.fileExists(atPath: usdzURL.path) else {
                throw NSError(domain: "RoomCapture", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Export succeeded but file not found"
                ])
            }

            // Read the USDZ data
            let data = try Data(contentsOf: usdzURL)
            debugPrint("🏠 [RoomCaptureVM] USDZ file size: \(data.count) bytes")

            // Clean up temp file
            try? FileManager.default.removeItem(at: usdzURL)

            return data
        }.value
    }

    /// Handle successful save operation
    private func handleSaveSuccess(_ scan: RoomScan) {
        isSaving = false
        isCapturing = false
        debugPrint("🏠 [RoomCaptureVM] ✅ Scan saved successfully: \(scan.name)")
        onComplete(scan)
    }

    /// Handle save error
    private func handleSaveError(_ error: Error) {
        debugPrint("🏠 [RoomCaptureVM] ❌ Save failed: \(error)")
        isSaving = false
        isCapturing = false
        errorMessage = "Failed to save scan: \(error.localizedDescription)"
    }

    /// Get ARSession for panorama capture
    var arSession: ARSession? {
        coordinator?.arSession
    }
}
