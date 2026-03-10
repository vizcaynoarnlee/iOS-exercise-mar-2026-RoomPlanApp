//
//  RoomViewerView.swift
//  RoomPlanApp
//
//  Main view for displaying 3D room scans with photos
//

import SwiftUI
import simd

struct RoomViewerView: View {
    @State private var viewModel: RoomViewerViewModel
    @State private var showPhotos = true

    init(scan: RoomScan) {
        _viewModel = State(initialValue: RoomViewerViewModel(scan: scan))
    }

    var body: some View {
        ZStack {
            // Main 3D scene view
            RoomSceneView(scan: viewModel.scan, showPhotos: showPhotos)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                topInfoBar
                Spacer()
                if !viewModel.scan.photos.isEmpty {
                    photoControlPanel
                }
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
            }
        }
        .navigationTitle("3D View")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - UI Components

    private var topInfoBar: some View {
        VStack(spacing: 0) {
            // Room title with Panorama button
            HStack(alignment: .center, spacing: 12) {
                Text(viewModel.scan.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // Spatial Panorama button (only show if photos exist)
                if !viewModel.scan.photos.isEmpty {
                    
                    NavigationLink(destination: SpatialPanoramaView(scan: viewModel.scan)) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.metering.multispot")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Panorama")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Photo count
            HStack(spacing: 4) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 11))
                Text("\(viewModel.scan.photos.count) photos")
                    .font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    private var photoControlPanel: some View {
        VStack(spacing: 12) {
            // Photo visibility control
            HStack(spacing: 12) {
                // Status indicator
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.scan.photos.count) Photos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Toggle button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPhotos.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showPhotos ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(showPhotos ? "Hide Photos" : "Show Photos")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(showPhotos ? Color.blue : Color.secondary)
                    .cornerRadius(10)
                }
            }

            // Divider
            Divider()
                .background(Color.secondary.opacity(0.3))

            // Instructions
            Text("Drag to orbit • Pinch to zoom • Double-tap to reset")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.9))
            .cornerRadius(25)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
    }
}

// MARK: - Previews

#Preview("Room with Photos - Light") {
    NavigationStack {
        RoomViewerView(scan: mockRoomScanWithPhotos())
    }
    .preferredColorScheme(.light)
}

#Preview("Room with Photos - Dark") {
    NavigationStack {
        RoomViewerView(scan: mockRoomScanWithPhotos())
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty Room - No Photos") {
    NavigationStack {
        RoomViewerView(scan: mockEmptyRoomScan())
    }
    .preferredColorScheme(.light)
}

// MARK: - Preview Helpers

private func mockRoomScanWithPhotos() -> RoomScan {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("preview_scan")

    // Create mock photos with spatial poses
    let photos = (0..<5).map { index in
        ScanPhoto(
            id: UUID(),
            imageURL: URL(fileURLWithPath: "/tmp/photo_\(index).jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(Float(index), 1.5, -2.0),
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date().addingTimeInterval(TimeInterval(-index * 60)),
            targetSurfaceID: nil
        )
    }

    return RoomScan(
        name: "Living Room Scan",
        usdURL: tempDir.appendingPathComponent("room.usdz"),
        captureDate: Date().addingTimeInterval(-3600),
        photos: photos,
        directory: tempDir
    )
}

private func mockEmptyRoomScan() -> RoomScan {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("empty_scan")

    return RoomScan(
        name: "Empty Room",
        usdURL: tempDir.appendingPathComponent("room.usdz"),
        captureDate: Date(),
        photos: [],
        directory: tempDir
    )
}

