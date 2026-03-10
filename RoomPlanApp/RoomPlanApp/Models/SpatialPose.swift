//
//  SpatialPose.swift
//  RoomPlan
//
//  Created by Arnlee Vizcayno on 3/8/26.
//

import Foundation
import simd

/// Represents a position and orientation in 3D space
/// Used to store where panoramas were captured relative to the room's coordinate system
struct SpatialPose: Codable, Sendable {
    /// Position in 3D space (X, Y, Z in meters)
    /// Uses ARKit/RoomPlan coordinate system: +X right, +Y up, +Z backward
    var position: SIMD3<Float>

    /// Orientation as a quaternion (x, y, z, w)
    /// Quaternions avoid gimbal lock and are standard in AR/VR systems
    var orientation: simd_quatf

    init(position: SIMD3<Float>, orientation: simd_quatf) {
        self.position = position
        self.orientation = orientation
    }
}

// MARK: - Codable Conformance for simd_quatf
extension SpatialPose {
    enum CodingKeys: String, CodingKey {
        case position
        case orientation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode position
        let positionArray = try container.decode([Float].self, forKey: .position)
        guard positionArray.count == 3 else {
            throw DecodingError.dataCorruptedError(
                forKey: .position,
                in: container,
                debugDescription: "Position array must contain exactly 3 elements"
            )
        }
        position = SIMD3<Float>(positionArray[0], positionArray[1], positionArray[2])

        // Decode orientation (quaternion as [x, y, z, w])
        let orientationArray = try container.decode([Float].self, forKey: .orientation)
        guard orientationArray.count == 4 else {
            throw DecodingError.dataCorruptedError(
                forKey: .orientation,
                in: container,
                debugDescription: "Orientation array must contain exactly 4 elements (x, y, z, w)"
            )
        }
        orientation = simd_quatf(
            ix: orientationArray[0],
            iy: orientationArray[1],
            iz: orientationArray[2],
            r: orientationArray[3]
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode position as array
        try container.encode([position.x, position.y, position.z], forKey: .position)

        // Encode orientation as array [x, y, z, w]
        try container.encode(
            [orientation.imag.x, orientation.imag.y, orientation.imag.z, orientation.real],
            forKey: .orientation
        )
    }
}
