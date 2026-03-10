//
//  AppConfiguration.swift
//  RoomPlanApp
//
//  Configuration constants used throughout the app
//

import Foundation
import CoreGraphics

enum AppConfiguration {
    /// Image processing settings
    enum Image {
        /// JPEG compression quality for saved photos (0.0 to 1.0)
        static let jpegCompressionQuality: CGFloat = 0.85

        /// Default scale for UIImage creation
        static let defaultScale: CGFloat = 1.0
    }

    /// File system settings
    enum FileSystem {
        /// Directory name for storing room scans
        static let scansDirectoryName = "RoomScans"

        /// Subdirectory name for photos within each scan
        static let photosDirectoryName = "photos"

        /// Filename for scan metadata JSON
        static let scanMetadataFilename = "scan.json"

        /// Filename for USDZ 3D model
        static let roomModelFilename = "room.usdz"
    }

    /// Naming conventions
    enum Naming {
        /// Default prefix for auto-generated room names
        static let defaultRoomNamePrefix = "Room Scan"
    }
}
