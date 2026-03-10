//
//  RoomScan.swift
//  RoomPlanApp
//
//  A completed room scan with 3D model and photos
//

import Foundation

/// Represents a completed room scan with 3D model and associated photos
///
/// Note: This is a class (not struct) to support @Observable for SwiftUI reactivity.
/// It conforms to @unchecked Sendable because:
/// - All mutations happen on @MainActor (via ViewModels)
/// - File URLs and dates are value types (thread-safe)
/// - The class is marked as final to prevent subclassing issues
@Observable
final class RoomScan: Codable, Identifiable, @unchecked Sendable {
    /// Unique identifier
    let id: UUID

    /// User-friendly name for this scan
    var name: String

    /// File URL to the USDZ 3D model file (relative to scan directory)
    var usdURL: URL

    /// When this room was scanned
    var captureDate: Date

    /// Photos captured during the scan with camera poses
    var photos: [ScanPhoto]

    /// Directory containing all scan files (USDZ, photos, metadata)
    var directory: URL

    enum CodingKeys: String, CodingKey {
        case id, name, usdURL, captureDate, photos, directory
    }

    init(id: UUID = UUID(), name: String, usdURL: URL, captureDate: Date, photos: [ScanPhoto] = [], directory: URL) {
        self.id = id
        self.name = name
        self.usdURL = usdURL
        self.captureDate = captureDate
        self.photos = photos
        self.directory = directory
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        usdURL = try container.decode(URL.self, forKey: .usdURL)
        captureDate = try container.decode(Date.self, forKey: .captureDate)
        photos = try container.decode([ScanPhoto].self, forKey: .photos)
        directory = try container.decode(URL.self, forKey: .directory)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(usdURL, forKey: .usdURL)
        try container.encode(captureDate, forKey: .captureDate)
        try container.encode(photos, forKey: .photos)
        try container.encode(directory, forKey: .directory)
    }
}
