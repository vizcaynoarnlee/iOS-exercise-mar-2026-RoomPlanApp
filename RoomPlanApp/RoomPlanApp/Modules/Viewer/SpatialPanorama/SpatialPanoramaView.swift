//
//  SpatialPanoramaView.swift
//  RoomPlanApp
//
//  360° panorama viewer - displays photos on sphere based on camera orientations
//

import SwiftUI
import SceneKit

struct SpatialPanoramaView: View {
    let scan: RoomScan
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = true
    @State private var processingStatus = "Preparing panorama..."
    @State private var processingProgress: Float = 0.0

    var body: some View {
        ZStack {
            // 360° panorama sphere view
            PanoramaSphereSceneView(
                photos: scan.photos,
                processingStatus: $processingStatus,
                processingProgress: $processingProgress,
                isProcessing: $isProcessing
            )
            .edgesIgnoringSafeArea(.all)

            // Processing overlay
            if isProcessing {
                VStack(spacing: 20) {
                    ProgressView(value: processingProgress) {
                        Text(processingStatus)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 300)

                    Text("\(Int(processingProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }

            // Overlay UI
            VStack {
                // Top bar with info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("360° Panorama")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(scan.photos.count) photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)

                Spacer()

                // Instructions
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "move.3d")
                            .foregroundStyle(.blue)
                        Text("Look around to explore")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }

                    Divider()
                        .background(Color.secondary.opacity(0.3))

                    Text("Drag to rotate • Pinch to zoom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("360° Panorama")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Panorama Sphere Scene View

struct PanoramaSphereSceneView: UIViewRepresentable {
    let photos: [ScanPhoto]
    @Binding var processingStatus: String
    @Binding var processingProgress: Float
    @Binding var isProcessing: Bool

    func makeUIView(context: Context) -> SCNView {
        debugPrint("🌐 [Panorama] Creating 360° panorama sphere...")
        let sceneView = SCNView()

        // Create scene
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .black

        // Create camera at origin (viewer is inside the sphere)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = PanoramaConfiguration.defaultFOV
        cameraNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        context.coordinator.cameraController.cameraNode = cameraNode

        // Add gestures for rotation
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator.cameraController,
            action: #selector(PanoramaCameraController.handlePan(_:))
        )
        sceneView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator.cameraController,
            action: #selector(PanoramaCameraController.handlePinch(_:))
        )
        sceneView.addGestureRecognizer(pinchGesture)

        // Create equirectangular panorama by stitching photos
        debugPrint("🌐 [Panorama] Stitching \(photos.count) photos into equirectangular image...")

        // Create panorama on background thread with progress updates
        var equirectangularImage: UIImage?

        DispatchQueue.global(qos: .userInitiated).async {
            equirectangularImage = PanoramaImageStitcher.createEquirectangularImage(
                from: photos
            ) { status, progress in
                DispatchQueue.main.async {
                    processingStatus = status
                    processingProgress = progress
                }
            }

            DispatchQueue.main.async {
                isProcessing = false

                if equirectangularImage == nil {
                    debugPrint("🌐 [Panorama] ❌ Failed to create equirectangular image")
                    return
                }

                debugPrint("🌐 [Panorama] ✅ Equirectangular image created")

                // Update scene with completed image
                context.coordinator.updateScene(
                    sceneView: sceneView,
                    image: equirectangularImage!
                )
            }
        }

        // Return scene view immediately (will be updated when processing completes)

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        let cameraController = PanoramaCameraController()

        func updateScene(sceneView: SCNView, image: UIImage) {
            guard let scene = sceneView.scene else { return }

            // Create sphere geometry with equirectangular texture
            let sphere = SCNSphere(radius: PanoramaConfiguration.sphereRadius)

            // Apply equirectangular image to sphere
            let material = SCNMaterial()
            material.diffuse.contents = image
            material.lightingModel = .constant  // Unlit
            material.cullMode = .front  // Show inside surface (camera is inside)
            material.isDoubleSided = false
            sphere.materials = [material]

            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(sphereNode)

            debugPrint("🌐 [Panorama] ✅ Sphere panorama viewer created")
        }
    }
}

// MARK: - Preview

#Preview("360° Panorama") {
    NavigationStack {
        SpatialPanoramaView(scan: RoomScan.mockPanoramaScan())
    }
}

// MARK: - Mock Data

#if DEBUG
extension RoomScan {
    static func mockPanoramaScan() -> RoomScan {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("panorama_preview")

        // Create photos around a circle (simulating 360° capture)
        let photos = (0..<8).map { index in
            let angle = Float(index) * Float.pi / 4.0  // 45° intervals

            // Create orientation quaternion pointing outward from circle
            let orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))

            return ScanPhoto(
                id: UUID(),
                imageURL: URL(fileURLWithPath: "/tmp/photo_\(index).jpg"),
                cameraPose: SpatialPose(
                    position: SIMD3<Float>(0, 1.5, 0),  // All from same position
                    orientation: orientation
                ),
                captureDate: Date().addingTimeInterval(TimeInterval(-index * 60)),
                targetSurfaceID: nil
            )
        }

        return RoomScan(
            name: "360° Panorama",
            usdURL: tempDir.appendingPathComponent("room.usdz"),
            captureDate: Date(),
            photos: photos,
            directory: tempDir
        )
    }
}
#endif
