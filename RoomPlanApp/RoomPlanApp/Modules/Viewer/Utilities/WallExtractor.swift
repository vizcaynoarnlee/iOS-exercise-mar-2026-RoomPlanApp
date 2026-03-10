//
//  WallExtractor.swift
//  RoomPlanApp
//
//  Extracts wall surfaces from RoomPlan 3D models
//

import SceneKit
import simd

// MARK: - Wall Surface

/// Represents a wall surface extracted from the room model
struct WallSurface {
    let node: SCNNode
    let position: SCNVector3
    let normal: SCNVector3  // Direction wall faces
    let width: CGFloat
    let height: CGFloat
}

// MARK: - Wall Extractor

struct WallExtractor {
    /// Extract wall surfaces from room scene
    static func extractWalls(from scene: SCNScene) -> [WallSurface] {
        var walls: [WallSurface] = []

        // Traverse scene graph looking for wall geometry
        scene.rootNode.enumerateChildNodes { node, _ in
            // Check if node has geometry and is vertical
            guard let geometry = node.geometry else { return }

            // RoomPlan can create various geometry types (planes, meshes, etc.)
            // Check by name first (RoomPlan often names walls)
            let nodeName = node.name?.lowercased() ?? ""
            let isWallByName = nodeName.contains("wall")

            // Check if vertical by transform
            let isVertical = isVerticalPlane(node: node)

            // Accept if either named as wall OR is vertical plane
            if isWallByName || (geometry is SCNPlane && isVertical) {
                // Calculate wall normal (direction it faces)
                // Z-axis of transform (column 2) gives the normal direction
                let worldTransform = node.worldTransform
                let zAxis = worldTransform.columns.2
                let normal = SCNVector3(zAxis.x, zAxis.y, zAxis.z)

                // Estimate dimensions (use bounding box if not a plane)
                var width: CGFloat = 2.0  // Default
                var height: CGFloat = 2.5  // Default

                if let plane = geometry as? SCNPlane {
                    width = plane.width
                    height = plane.height
                } else {
                    // Use bounding box for meshes
                    let bbox = node.boundingBox
                    let size = SCNVector3(
                        bbox.max.x - bbox.min.x,
                        bbox.max.y - bbox.min.y,
                        bbox.max.z - bbox.min.z
                    )
                    width = CGFloat(max(size.x, size.z))
                    height = CGFloat(size.y)
                }

                let wall = WallSurface(
                    node: node,
                    position: node.worldPosition,
                    normal: normalize(normal),
                    width: width,
                    height: height
                )

                walls.append(wall)
                debugPrint("🎨 [Walls] Found wall '\(node.name ?? "unnamed")' at \(wall.position), normal: \(wall.normal), size: \(width)x\(height)")
            }
        }

        debugPrint("🎨 [Walls] Total walls found: \(walls.count)")
        return walls
    }

    /// Check if node represents a vertical plane (likely a wall)
    private static func isVerticalPlane(node: SCNNode) -> Bool {
        guard let _ = node.geometry as? SCNPlane else { return false }

        // Get the up vector in world space (Y-axis = column 1)
        let worldTransform = node.worldTransform
        let yAxis = worldTransform.columns.1
        let upVector = SCNVector3(yAxis.x, yAxis.y, yAxis.z)

        // If Y component is dominant, it's vertical
        return abs(upVector.y) > 0.8
    }

    /// Find the wall that the camera is most likely facing
    static func findNearestWall(from position: SIMD3<Float>, facing direction: SIMD3<Float>, walls: [WallSurface]) -> WallSurface? {
        var bestWall: WallSurface?
        var bestScore: Float = -1.0

        for wall in walls {
            // Vector from camera to wall
            let toWall = SIMD3<Float>(
                wall.position.x - position.x,
                wall.position.y - position.y,
                wall.position.z - position.z
            )

            let distance = length(toWall)
            guard distance > 0.1 else { continue }  // Too close

            let toWallNorm = normalize(toWall)

            // Check if camera is facing this wall
            let facingAlignment = dot(direction, toWallNorm)
            guard facingAlignment > 0.5 else { continue }  // Not facing this wall

            // Check if wall is facing camera (wall normal points toward camera)
            let wallNormal = SIMD3<Float>(wall.normal.x, wall.normal.y, wall.normal.z)
            let wallFacingCamera = dot(-toWallNorm, wallNormal)
            guard wallFacingCamera > 0.5 else { continue }  // Wall facing away

            // Score based on alignment and distance (closer and better aligned = higher score)
            let score = facingAlignment * wallFacingCamera / (distance + 1.0)

            if score > bestScore {
                bestScore = score
                bestWall = wall
            }
        }

        if bestWall != nil {
            debugPrint("🎨 [FindWall] Found wall with score: \(bestScore)")
        }

        return bestWall
    }
}
