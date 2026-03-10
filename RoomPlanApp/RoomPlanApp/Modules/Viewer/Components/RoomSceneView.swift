//
//  RoomSceneView.swift
//  RoomPlanApp
//
//  SceneKit view for displaying 3D room models with photos
//

import SwiftUI
import SceneKit
import simd

struct RoomSceneView: UIViewRepresentable {
    let scan: RoomScan
    let showPhotos: Bool

    func makeUIView(context: Context) -> SCNView {
        debugPrint("🎨 [RoomViewer] Creating 3D scene...")
        let sceneView = SCNView()

        // Create scene
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .systemBackground

        // Create orbit camera
        let orbitCamera = OrbitCamera()
        scene.rootNode.addChildNode(orbitCamera.cameraNode)
        scene.rootNode.addChildNode(orbitCamera.targetNode)  // Add target node to scene
        context.coordinator.orbitCamera = orbitCamera

        // Add gestures
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        sceneView.addGestureRecognizer(pinchGesture)

        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        sceneView.addGestureRecognizer(doubleTapGesture)

        // Load room model
        let roomURL = scan.usdURL
        if true {
            debugPrint("🎨 [RoomViewer] Loading room model from: \(roomURL.lastPathComponent)")
            Task { @MainActor in
                do {
                    let loadedScene = try SCNScene(url: roomURL)
                    scene.rootNode.addChildNode(loadedScene.rootNode)
                    debugPrint("🎨 [RoomViewer] ✅ Room model loaded")

                    // Calculate room bounds and frame camera
                    let (minBounds, maxBounds) = loadedScene.rootNode.boundingBox
                    let roomCenter = SIMD3<Float>(
                        (minBounds.x + maxBounds.x) / 2,
                        (minBounds.y + maxBounds.y) / 2,
                        (minBounds.z + maxBounds.z) / 2
                    )

                    let roomSize = SIMD3<Float>(
                        maxBounds.x - minBounds.x,
                        maxBounds.y - minBounds.y,
                        maxBounds.z - minBounds.z
                    )

                    // Calculate distance based on room size
                    let maxExtent = max(max(roomSize.x, roomSize.y), roomSize.z)
                    let distance = max(maxExtent * 1.5, 1.0)  // At least 1m away

                    // Frame camera on room
                    context.coordinator.orbitCamera?.frameTarget(at: roomCenter, distance: distance)

                    debugPrint("🎨 [RoomViewer] Room center: \(roomCenter), maxExtent: \(maxExtent)")
                    debugPrint("🎨 [RoomViewer] Camera framed at distance: \(distance)")

                    // Debug: Log scene structure
                    debugPrint("🎨 [RoomViewer] Scene structure:")
                    loadedScene.rootNode.enumerateChildNodes { node, _ in
                        let geometryType = node.geometry != nil ? String(describing: type(of: node.geometry!)) : "no geometry"
                        debugPrint("🎨 [RoomViewer]   - Node: '\(node.name ?? "unnamed")', geometry: \(geometryType)")
                    }

                    // Add scan photos mapped to walls after room loads
                    if !scan.photos.isEmpty {
                        debugPrint("🎨 [RoomViewer] Mapping \(scan.photos.count) photos to walls...")
                        let photoNodes = PhotoNodeBuilder.createPhotoNodes(
                            from: scan.photos,
                            roomScene: loadedScene
                        )
                        // Store photo nodes in coordinator for visibility toggling
                        context.coordinator.photoNodes = photoNodes
                        for node in photoNodes {
                            scene.rootNode.addChildNode(node)
                        }
                        // Set initial visibility
                        context.coordinator.updatePhotoVisibility(showPhotos: self.showPhotos)
                        debugPrint("🎨 [RoomViewer] ✅ Scan photos added to scene")
                    }
                } catch {
                    debugPrint("🎨 [RoomViewer] ❌ Failed to load room model: \(error)")
                }
            }
        } else {
            debugPrint("🎨 [RoomViewer] ⚠️ No room model available")

            // No room model, but still show scan photos if available
            if !scan.photos.isEmpty {
                debugPrint("🎨 [RoomViewer] Adding \(scan.photos.count) photos without room model...")
                let photoNodes = PhotoNodeBuilder.createPhotoNodes(
                    from: scan.photos,
                    roomScene: nil
                )
                // Store photo nodes in coordinator for visibility toggling
                context.coordinator.photoNodes = photoNodes
                for node in photoNodes {
                    scene.rootNode.addChildNode(node)
                }
                // Set initial visibility
                context.coordinator.updatePhotoVisibility(showPhotos: self.showPhotos)
            }

            // Set default camera framing (no room to calculate from)
            context.coordinator.orbitCamera?.frameTarget(at: SIMD3<Float>(0, 0, 0), distance: 5.0)
            debugPrint("🎨 [RoomViewer] Using default camera position (no room model)")
        }

        debugPrint("🎨 [RoomViewer] ✅ Scene setup complete")

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update photo visibility when toggle changes
        context.coordinator.updatePhotoVisibility(showPhotos: showPhotos)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var orbitCamera: OrbitCamera?
        var photoNodes: [SCNNode] = []
        var initialAzimuth: Float = 0.0
        var initialElevation: Float = 0.0
        var initialDistance: Float = 4.0

        /// Update visibility of all photo nodes
        func updatePhotoVisibility(showPhotos: Bool) {
            for node in photoNodes {
                node.isHidden = !showPhotos
            }
            if !photoNodes.isEmpty {
                debugPrint("🎨 [PhotoToggle] Photos \(showPhotos ? "shown" : "hidden") - \(photoNodes.count) nodes")
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let camera = orbitCamera, let view = gesture.view else { return }

            if gesture.state == .began {
                // Store initial camera state
                initialAzimuth = camera.azimuth
                initialElevation = camera.elevation
                debugPrint("🎥 [Pan] Started - initial azimuth: \(initialAzimuth), elevation: \(initialElevation)")

            } else if gesture.state == .changed {
                // Get total translation from gesture start
                let translation = gesture.translation(in: view)

                // Convert pixels to radians (sensitivity tuned for smooth control)
                let azimuthOffset = -Float(translation.x) * 0.002  // Reduced sensitivity for smoother feel
                let elevationOffset = Float(translation.y) * 0.002

                // Set absolute position = initial + offset
                let newAzimuth = initialAzimuth + azimuthOffset
                let newElevation = initialElevation + elevationOffset

                camera.setOrbit(azimuth: newAzimuth, elevation: newElevation)

            } else if gesture.state == .ended || gesture.state == .cancelled {
                // Get gesture velocity in points per second
                let velocity = gesture.velocity(in: view)

                // Convert to radians per second (matching translation sensitivity)
                let azimuthVelocity = -Float(velocity.x) * 0.002
                let elevationVelocity = Float(velocity.y) * 0.002

                // Apply momentum with velocity
                camera.applyMomentum(azimuthVelocity: azimuthVelocity, elevationVelocity: elevationVelocity)

                debugPrint("🎥 [Pan] Ended - applying momentum with velocity: (\(azimuthVelocity), \(elevationVelocity))")
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let camera = orbitCamera else { return }

            if gesture.state == .began {
                initialDistance = camera.distance
                debugPrint("🎥 [Pinch] Started - initial distance: \(initialDistance)")
            } else if gesture.state == .changed {
                // Calculate zoom based on scale from 1.0
                // scale > 1.0 = pinch out = zoom out (increase distance)
                // scale < 1.0 = pinch in = zoom in (decrease distance)
                let scaleFactor = Float(gesture.scale)
                let newDistance = initialDistance / scaleFactor  // Inverted for natural feel

                camera.applyZoom(delta: newDistance - camera.distance)
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let camera = orbitCamera else { return }
            camera.reset()
            debugPrint("🎥 [DoubleTap] Camera reset")
        }
    }
}
