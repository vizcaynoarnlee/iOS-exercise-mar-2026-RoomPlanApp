//
//  PersistenceService.swift
//  RoomPlanApp
//
//  Service for persisting and loading RoomScan data to/from disk
//

import Foundation
import UIKit

typealias PlatformImage = UIImage

/// Service for persisting and loading RoomScan data to/from disk
final class PersistenceService: Sendable {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default
    private let scansDirectory: URL

    private init() {
        // iOS: Use Documents directory for user-visible app data
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        scansDirectory = documentsURL.appendingPathComponent(
            AppConfiguration.FileSystem.scansDirectoryName,
            isDirectory: true
        )

        debugPrint("💾 [PersistenceService] iOS Documents directory: \(documentsURL.path)")
        debugPrint("💾 [PersistenceService] Scans directory: \(scansDirectory.path)")

        // Create scans directory if it doesn't exist
        do {
            if !fileManager.fileExists(atPath: scansDirectory.path) {
                debugPrint("💾 [PersistenceService] Creating scans directory...")
                try fileManager.createDirectory(
                    at: scansDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                debugPrint("💾 [PersistenceService] ✅ Scans directory created")
            } else {
                debugPrint("💾 [PersistenceService] ✅ Scans directory exists")
            }

            // Test write permissions
            let testFile = scansDirectory.appendingPathComponent(".test")
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            debugPrint("💾 [PersistenceService] ✅ Directory is writable")
        } catch {
            debugPrint("💾 [PersistenceService] ❌ Setup failed: \(error)")
            debugPrint("💾 [PersistenceService] ❌ Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Room Scan Management

    /// Load all scans from disk
    func loadAllScans() throws -> [RoomScan] {
        debugPrint("💾 [PersistenceService] Loading all scans...")

        guard fileManager.fileExists(atPath: scansDirectory.path) else {
            debugPrint("💾 [PersistenceService] Scans directory doesn't exist yet")
            return []
        }

        let scanFolders = try fileManager.contentsOfDirectory(
            at: scansDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }

        debugPrint("💾 [PersistenceService] Found \(scanFolders.count) scan folders")

        let scans = scanFolders.compactMap { folderURL in
            try? loadScan(from: folderURL)
        }

        debugPrint("💾 [PersistenceService] Loaded \(scans.count) scans successfully")
        return scans
    }

    /// Load a single scan from a directory
    private func loadScan(from directory: URL) throws -> RoomScan {
        debugPrint("💾 [PersistenceService] Loading scan from: \(directory.lastPathComponent)")
        let scanFileURL = directory.appendingPathComponent(AppConfiguration.FileSystem.scanMetadataFilename)
        let data = try Data(contentsOf: scanFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var scan = try decoder.decode(RoomScan.self, from: data)

        // IMPORTANT: Update paths based on current app container
        // This ensures paths are valid even after app reinstallation
        updateScanPaths(&scan)

        debugPrint("💾 [PersistenceService] ✅ Loaded scan: \(scan.name)")
        debugPrint("💾 [PersistenceService] Scan directory: \(scan.directory.path)")
        debugPrint("💾 [PersistenceService] Fixed \(scan.photos.count) photo URLs")

        return scan
    }

    /// Update scan file paths to match current app container
    private func updateScanPaths(_ scan: inout RoomScan) {
        scan.directory = scansDirectory.appendingPathComponent(scan.id.uuidString, isDirectory: true)
        scan.usdURL = scan.directory.appendingPathComponent(AppConfiguration.FileSystem.roomModelFilename)
        updatePhotoURLs(&scan)
    }

    /// Update photo URLs to match current scan directory
    private func updatePhotoURLs(_ scan: inout RoomScan) {
        guard !scan.photos.isEmpty else { return }

        let photosDir = scan.directory.appendingPathComponent(
            AppConfiguration.FileSystem.photosDirectoryName,
            isDirectory: true
        )

        for i in 0..<scan.photos.count {
            let photoID = scan.photos[i].id
            scan.photos[i].imageURL = photosDir.appendingPathComponent("\(photoID.uuidString).jpg")
        }
    }

    /// Save a scan to disk (internal helper)
    private func saveScan(_ scan: RoomScan) throws {
        debugPrint("💾 [PersistenceService] Saving scan: \(scan.name)")

        // Ensure scan directory exists
        try fileManager.createDirectory(
            at: scan.directory,
            withIntermediateDirectories: true
        )

        // Ensure photos subdirectory exists
        let photosDir = scan.directory.appendingPathComponent(
            AppConfiguration.FileSystem.photosDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: photosDir,
            withIntermediateDirectories: true
        )

        // Save scan metadata as JSON
        let scanFileURL = scan.directory.appendingPathComponent(AppConfiguration.FileSystem.scanMetadataFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(scan)
        try data.write(to: scanFileURL)

        debugPrint("💾 [PersistenceService] ✅ Scan saved to: \(scanFileURL.path)")
    }

    /// Delete a scan and all its files
    func deleteScan(_ scan: RoomScan) throws {
        debugPrint("💾 [PersistenceService] Deleting scan: \(scan.name)")
        try fileManager.removeItem(at: scan.directory)
        debugPrint("💾 [PersistenceService] ✅ Scan deleted")
    }

    // MARK: - Room Data

    /// Save completed room scan with USDZ and photos
    func saveCompletedScan(
        name: String,
        usdzData: Data,
        photos: [(image: UIImage, pose: SpatialPose)]
    ) throws -> RoomScan {
        debugPrint("💾 [PersistenceService] ===== SAVE COMPLETED SCAN =====")
        debugPrint("💾 [PersistenceService] Name: \(name)")
        debugPrint("💾 [PersistenceService] USDZ size: \(usdzData.count) bytes")
        debugPrint("💾 [PersistenceService] Photos: \(photos.count)")

        // Create scan directory
        let scanID = UUID()
        let scanDir = scansDirectory.appendingPathComponent(scanID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: scanDir, withIntermediateDirectories: true)

        // Save USDZ file
        let roomURL = scanDir.appendingPathComponent(AppConfiguration.FileSystem.roomModelFilename)
        try usdzData.write(to: roomURL)
        debugPrint("💾 [PersistenceService] ✅ USDZ file saved")

        // Create photos directory
        let photosDir = scanDir.appendingPathComponent(
            AppConfiguration.FileSystem.photosDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        // Save photos
        var savedPhotos: [ScanPhoto] = []
        for (index, photoData) in photos.enumerated() {
            let photoID = UUID()
            let photoURL = photosDir.appendingPathComponent("\(photoID.uuidString).jpg")

            guard let imageData = photoData.image.jpegData(
                compressionQuality: AppConfiguration.Image.jpegCompressionQuality
            ) else {
                debugPrint("💾 [PersistenceService] ❌ Failed to compress photo \(index + 1)")
                throw PersistenceError.imageCompressionFailed
            }

            try imageData.write(to: photoURL)

            let scanPhoto = ScanPhoto(
                id: photoID,
                imageURL: photoURL,
                cameraPose: photoData.pose,
                captureDate: Date(),
                targetSurfaceID: nil
            )
            savedPhotos.append(scanPhoto)

            debugPrint("💾 [PersistenceService] ✅ Photo \(index + 1)/\(photos.count) saved")
        }

        // Create RoomScan object
        let scan = RoomScan(
            id: scanID,
            name: name,
            usdURL: roomURL,
            captureDate: Date(),
            photos: savedPhotos,
            directory: scanDir
        )

        // Save metadata
        try saveScan(scan)

        debugPrint("💾 [PersistenceService] ✅ Completed scan saved successfully")
        return scan
    }

}

// MARK: - Errors

enum PersistenceError: LocalizedError {
    case scanNotFound
    case imageCompressionFailed
    case invalidData
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .scanNotFound:
            return "Scan not found"
        case .imageCompressionFailed:
            return "Failed to compress image"
        case .fileNotFound:
            return "File not found after writing"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
