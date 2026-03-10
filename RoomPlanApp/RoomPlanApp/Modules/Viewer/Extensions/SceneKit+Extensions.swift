//
//  SceneKitExtensions.swift
//  RoomPlanApp
//
//  SceneKit utility extensions for 3D viewer
//

import SceneKit
import simd

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x*x + y*y + z*z)
        guard length > 0 else { return SCNVector3(0, 0, 0) }
        return SCNVector3(x/length, y/length, z/length)
    }
}

func normalize(_ vector: SCNVector3) -> SCNVector3 {
    return vector.normalized()
}

// MARK: - SCNNode Extensions

extension SCNNode {
    var worldTransform: simd_float4x4 {
        return simd_float4x4(self.transform)
    }
}
