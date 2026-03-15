//
//  DashboardView.swift
//  RoomPlan
//
//  Created by Arnlee Vizcayno on 3/8/26.
//

import SwiftUI
import simd

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var selectedScan: RoomScan?
    @State private var showingViewer = false
    @State private var showingScanner = false
    @State private var showingAssets = false
    @State private var scanForAssets: RoomScan?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading scans...")
                } else if viewModel.scans.isEmpty {
                    emptyStateView
                } else {
                    scanListView
                }
            }
            .navigationTitle("Room List")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        startNewScan()
                    }) {
                        Label("Scan Room", systemImage: "camera.fill")
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                NavigationStack {
                    RoomCaptureView { scan in
                        showingScanner = false
                        // Reload scans after capture
                        viewModel.loadScans()
                    }
                }
            }
            .navigationDestination(isPresented: $showingViewer) {
                if let scan = selectedScan {
                    RoomViewerView(scan: scan)
                }
            }
            .sheet(isPresented: $showingAssets) {
                if let scan = scanForAssets {
                    ScanAssetsView(scan: scan)
                }
            }
        }
        .task {
            viewModel.loadScans()
        }
    }

    private func startNewScan() {
        // Open scanner directly - scan will be created when complete
        showingScanner = true
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)

                VStack(spacing: 8) {
                    Text("No Room Scans")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Scan a room to create a 3D model\nwith photos mapped to walls")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Button(action: {
                startNewScan()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Scan Your First Room")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    private var scanListView: some View {
        List {
            ForEach(viewModel.scans) { scan in
                ScanRow(scan: scan, onShareTapped: {
                    scanForAssets = scan
                    showingAssets = true
                })
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedScan = scan
                    showingViewer = true
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color(.label).opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteScan(viewModel.scans[index])
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.loadScans()
        }
    }
}

struct ScanRow: View {
    let scan: RoomScan
    let onShareTapped: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail/Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "cube.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(scan.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Photo count
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 11))
                    Text("\(scan.photos.count) photos")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.green)

                // Date
                Text(scan.captureDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            // Share button
            Button(action: {
                onShareTapped()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Tap indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.clear)
    }
}

// MARK: - Preview Helpers

// Preview sample data
private func makeSampleScans() -> [RoomScan] {
    let scan1 = RoomScan(
        name: "Living Room",
        usdURL: URL(fileURLWithPath: "/tmp/living-room/room.usdz"),
        captureDate: Date().addingTimeInterval(-3600 * 24 * 2),
        photos: [
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo1.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(0, 1.5, 0),
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        ),
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo2.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(1, 1.5, 0),
                orientation: simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        ),
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo3.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(2, 1.5, 0),
                orientation: simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        ),
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo4.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(3, 1.5, 0),
                orientation: simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        ),
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo5.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(4, 1.5, 0),
                orientation: simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        )
    ],
        directory: URL(fileURLWithPath: "/tmp/living-room")
    )

    let scan2 = RoomScan(
        name: "Master Bedroom",
        usdURL: URL(fileURLWithPath: "/tmp/bedroom/room.usdz"),
        captureDate: Date().addingTimeInterval(-3600 * 5),
        photos: [
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo1.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(0, 1.5, 0),
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        ),
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo2.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(1, 1.5, 0),
                orientation: simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        ),
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo3.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(2, 1.5, 0),
                orientation: simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        )
    ],
        directory: URL(fileURLWithPath: "/tmp/bedroom")
    )

    let scan3 = RoomScan(
        name: "Kitchen & Dining",
        usdURL: URL(fileURLWithPath: "/tmp/kitchen/room.usdz"),
        captureDate: Date().addingTimeInterval(-3600),
        photos: [
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo1.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(0, 1.5, 0),
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        ),
        ScanPhoto(
            imageURL: URL(fileURLWithPath: "/tmp/photo2.jpg"),
            cameraPose: SpatialPose(
                position: SIMD3<Float>(1, 1.5, 0),
                orientation: simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
            ),
            captureDate: Date()
        )
    ],
        directory: URL(fileURLWithPath: "/tmp/kitchen")
    )

    return [scan1, scan2, scan3]
}

#Preview("Empty State - Light Mode") {
    DashboardView()
        .preferredColorScheme(.light)
}

#Preview("Empty State - Dark Mode") {
    DashboardView()
        .preferredColorScheme(.dark)
}

#Preview("With Scans - Light Mode") {
    NavigationStack {
        List {
            ForEach(makeSampleScans()) { scan in
                ScanRow(scan: scan, onShareTapped: {})
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color(.label).opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Room Scans")
    }
    .preferredColorScheme(.light)
}

#Preview("With Scans - Dark Mode") {
    NavigationStack {
        List {
            ForEach(makeSampleScans()) { scan in
                ScanRow(scan: scan, onShareTapped: {})
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color(.label).opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Room Scans")
    }
    .preferredColorScheme(.dark)
}
