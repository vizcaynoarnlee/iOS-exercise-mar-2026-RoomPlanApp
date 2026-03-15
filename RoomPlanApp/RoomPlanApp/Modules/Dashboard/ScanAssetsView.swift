//
//  ScanAssetsView.swift
//  RoomPlanApp
//
//  Modal view displaying all scan assets (USDZ, JSON, images)
//

import SwiftUI
import UniformTypeIdentifiers
import simd

struct ScanAssetsView: View {
    let scan: RoomScan
    @Environment(\.dismiss) private var dismiss
    @State private var assets: [ScanAsset] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Subtitle
                VStack(spacing: 4) {
                    Text("Data that can be shared")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))

                Divider()

                // Content
                Group {
                    if isLoading {
                        ProgressView("Loading assets...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if assets.isEmpty {
                        emptyStateView
                    } else {
                        assetListView
                    }
                }
            }
            .navigationTitle("Scan Assets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: scan.directory,
                        subject: Text("Room Scan: \(scan.name)"),
                        message: Text("Sharing scan folder with \(assets.count) files")
                    ) {
                        Label("Share All", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            loadAssets()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Assets Found")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Unable to find scan files in directory")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var assetListView: some View {
        List {
            // Scan info section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scan.name)
                        .font(.headline)

                    HStack(spacing: 16) {
                        Label("\(scan.photos.count) photos", systemImage: "photo.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label(
                            scan.captureDate.formatted(date: .abbreviated, time: .shortened),
                            systemImage: "clock.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Text(scan.directory.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Scan Information")
            }

            // Assets by type
            Section {
                ForEach(assets.filter { $0.type == .usdz }) { asset in
                    AssetRow(asset: asset)
                }
            } header: {
                Text("3D Model")
            }

            Section {
                ForEach(assets.filter { $0.type == .json }) { asset in
                    AssetRow(asset: asset)
                }
            } header: {
                Text("Metadata")
            }

            Section {
                ForEach(assets.filter { $0.type == .image }) { asset in
                    AssetRow(asset: asset)
                }
            } header: {
                Text("Images (\(assets.filter { $0.type == .image }.count))")
            }

            // Other files
            let otherAssets = assets.filter { $0.type == .other }
            if !otherAssets.isEmpty {
                Section {
                    ForEach(otherAssets) { asset in
                        AssetRow(asset: asset)
                    }
                } header: {
                    Text("Other Files")
                }
            }
        }
    }

    private func loadAssets() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var discoveredAssets: [ScanAsset] = []

            // Add USDZ file
            if FileManager.default.fileExists(atPath: scan.usdURL.path) {
                discoveredAssets.append(ScanAsset(url: scan.usdURL, type: .usdz))
            }

            // Add photo files
            for photo in scan.photos {
                if FileManager.default.fileExists(atPath: photo.imageURL.path) {
                    discoveredAssets.append(ScanAsset(url: photo.imageURL, type: .image))
                }
            }

            // Scan directory for metadata and other files
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: scan.directory,
                    includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                    options: [.skipsHiddenFiles]
                )

                for url in contents {
                    // Skip files already added
                    if discoveredAssets.contains(where: { $0.url == url }) {
                        continue
                    }

                    let fileExtension = url.pathExtension.lowercased()
                    let type: ScanAssetType

                    switch fileExtension {
                    case "json":
                        type = .json
                    case "jpg", "jpeg", "png", "heic":
                        type = .image
                    case "usdz", "usd":
                        type = .usdz
                    default:
                        type = .other
                    }

                    discoveredAssets.append(ScanAsset(url: url, type: type))
                }
            } catch {
                debugPrint("⚠️ [Assets] Failed to scan directory: \(error)")
            }

            // Sort: USDZ, JSON, Images, Other
            discoveredAssets.sort { asset1, asset2 in
                if asset1.type != asset2.type {
                    return asset1.type.sortOrder < asset2.type.sortOrder
                }
                return asset1.url.lastPathComponent < asset2.url.lastPathComponent
            }

            DispatchQueue.main.async {
                self.assets = discoveredAssets
                self.isLoading = false
            }
        }
    }
}

// MARK: - Asset Row

struct AssetRow: View {
    let asset: ScanAsset
    @State private var fileSize: String = "..."

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: asset.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(asset.type.color)
                .frame(width: 32, height: 32)
                .background(asset.type.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.url.lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(asset.type.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(fileSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Share button
            ShareLink(item: asset.url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .task {
            loadFileSize()
        }
    }

    private func loadFileSize() {
        DispatchQueue.global(qos: .utility).async {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: asset.url.path)
                if let size = attributes[.size] as? Int64 {
                    let formatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                    DispatchQueue.main.async {
                        self.fileSize = formatted
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.fileSize = "Unknown"
                }
            }
        }
    }
}

// MARK: - Asset Model

struct ScanAsset: Identifiable {
    let id = UUID()
    let url: URL
    let type: ScanAssetType
}

enum ScanAssetType: Sendable {
    case usdz
    case json
    case image
    case other

    var displayName: String {
        switch self {
        case .usdz: return "3D Model"
        case .json: return "Metadata"
        case .image: return "Image"
        case .other: return "File"
        }
    }

    var icon: String {
        switch self {
        case .usdz: return "cube.fill"
        case .json: return "doc.text.fill"
        case .image: return "photo.fill"
        case .other: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .usdz: return .blue
        case .json: return .orange
        case .image: return .green
        case .other: return .gray
        }
    }

    var sortOrder: Int {
        switch self {
        case .usdz: return 0
        case .json: return 1
        case .image: return 2
        case .other: return 3
        }
    }
}

// MARK: - Preview

#Preview("Scan Assets") {
    ScanAssetsView(scan: RoomScan(
        name: "Living Room",
        usdURL: URL(fileURLWithPath: "/tmp/living-room/room.usdz"),
        captureDate: Date(),
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
            )
        ],
        directory: URL(fileURLWithPath: "/tmp/living-room")
    ))
}
