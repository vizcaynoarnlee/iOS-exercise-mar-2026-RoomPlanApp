//
//  PanoramaCameraController.swift
//  RoomPlanApp
//
//  Handles camera controls and gestures for panorama viewer
//

import Foundation
import SceneKit
import UIKit

/// Manages camera rotation and zoom gestures for panorama viewing
final class PanoramaCameraController: NSObject {

    // MARK: - Properties

    var cameraNode: SCNNode?

    private var currentYaw: Float = 0.0      // Horizontal rotation
    private var currentPitch: Float = 0.0    // Vertical rotation
    private var currentZoom: Float = Float(PanoramaConfiguration.defaultFOV)

    // MARK: - Gesture Handlers

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let camera = cameraNode else { return }

        switch gesture.state {
        case .changed:
            let translation = gesture.translation(in: gesture.view)

            // Update rotation angles
            currentYaw += Float(translation.x) * PanoramaConfiguration.panSensitivity
            currentPitch -= Float(translation.y) * PanoramaConfiguration.panSensitivity  // Inverted for natural feel

            // Clamp pitch to prevent gimbal lock
            let clampMargin = PanoramaConfiguration.pitchClampMargin
            currentPitch = max(-Float.pi / 2 + clampMargin, min(Float.pi / 2 - clampMargin, currentPitch))

            // Apply rotation to camera
            camera.eulerAngles = SCNVector3(currentPitch, currentYaw, 0)

            // Reset gesture translation for delta tracking
            gesture.setTranslation(.zero, in: gesture.view)

        default:
            break
        }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let camera = cameraNode?.camera else { return }

        switch gesture.state {
        case .changed:
            let scale = Float(gesture.scale)

            // Adjust field of view (smaller FOV = zoomed in)
            currentZoom /= scale

            // Clamp zoom to configured range
            currentZoom = max(
                Float(PanoramaConfiguration.minFOV),
                min(Float(PanoramaConfiguration.maxFOV), currentZoom)
            )

            camera.fieldOfView = CGFloat(currentZoom)

            gesture.scale = 1.0

        default:
            break
        }
    }
}
