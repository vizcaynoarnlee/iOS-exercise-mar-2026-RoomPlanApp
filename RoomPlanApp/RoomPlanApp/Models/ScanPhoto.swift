//
//  ScanPhoto.swift
//  RoomPlanApp
//
//  Created by Arnlee Vizcayno on 3/9/26.
//

import Foundation
import simd

/// Represents a photo captured during room scanning
/// Photos are captured at various positions and facing different surfaces
struct ScanPhoto: Codable, Identifiable, Sendable {
    /// Unique identifier for this photo
    let id: UUID

    /// File URL pointing to the captured image
    var imageURL: URL

    /// Camera pose when photo was captured (position + orientation)
    var cameraPose: SpatialPose

    /// When this photo was captured
    var captureDate: Date

    /// Optional: Surface identifier that this photo faces
    /// Can be used to map photo onto specific wall in 3D model
    var targetSurfaceID: UUID?

    init(
        id: UUID = UUID(),
        imageURL: URL,
        cameraPose: SpatialPose,
        captureDate: Date = Date(),
        targetSurfaceID: UUID? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.cameraPose = cameraPose
        self.captureDate = captureDate
        self.targetSurfaceID = targetSurfaceID
    }
}
