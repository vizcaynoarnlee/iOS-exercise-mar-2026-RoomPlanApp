//
//  PhotoNodeBuilder.swift
//  RoomPlanApp
//
//  Creates SceneKit nodes for displaying photos in 3D space
//

import UIKit
import SceneKit
import simd

struct PhotoNodeBuilder {
    /// Create photo nodes from scan photos, mapped to walls if available
    static func createPhotoNodes(from scanPhotos: [ScanPhoto], roomScene: SCNScene?) -> [SCNNode] {
        var photoNodes: [SCNNode] = []

        // Extract walls from room scene if available
        let walls = roomScene != nil ? WallExtractor.extractWalls(from: roomScene!) : []
        debugPrint("🎨 [ScanPhotos] Found \(walls.count) walls in room model")

        for (index, photo) in scanPhotos.enumerated() {
            debugPrint("🎨 [ScanPhotos] Processing photo \(index + 1)/\(scanPhotos.count)")

            // Load image
            guard let imageData = try? Data(contentsOf: photo.imageURL),
                  let image = UIImage(data: imageData) else {
                debugPrint("🎨 [ScanPhotos] ❌ Failed to load image: \(photo.imageURL.lastPathComponent)")
                continue
            }

            // Create photo node
            let photoNode: SCNNode
            if !walls.isEmpty {
                // Map photo to nearest wall (with index for z-offset)
                photoNode = createPhotoOnWall(
                    image: image,
                    cameraPose: photo.cameraPose,
                    walls: walls,
                    photoIndex: index
                )
            } else {
                // No walls, position at camera pose
                photoNode = createPhotoAtPose(
                    image: image,
                    cameraPose: photo.cameraPose
                )
            }

            photoNode.name = "scan_photo_\(photo.id.uuidString)"
            photoNode.renderingOrder = index  // Explicit rendering order to prevent z-fighting
            photoNodes.append(photoNode)

            debugPrint("🎨 [ScanPhotos] ✅ Added photo at position: \(photo.cameraPose.position)")
        }

        return photoNodes
    }

    /// Create photo node positioned at camera pose (no wall mapping)
    private static func createPhotoAtPose(image: UIImage, cameraPose: SpatialPose) -> SCNNode {
        // Calculate photo dimensions based on image aspect ratio
        let aspectRatio = image.size.width / image.size.height
        let height: CGFloat = 2.0  // 2 meters tall
        let width = height * aspectRatio

        // Create plane
        let plane = SCNPlane(width: width, height: height)

        // Apply texture
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.lightingModel = .constant
        material.isDoubleSided = false
        plane.materials = [material]

        let planeNode = SCNNode(geometry: plane)

        // Position at camera location
        planeNode.position = SCNVector3(
            cameraPose.position.x,
            cameraPose.position.y,
            cameraPose.position.z
        )

        // Orient to face the direction camera was looking
        // Camera looks along -Z axis in its local space
        let forward = cameraPose.orientation.act(SIMD3<Float>(0, 0, -1))

        // Calculate rotation to face forward direction
        // We want photo to face AWAY from camera, so use opposite direction
        let targetDirection = -forward
        planeNode.look(at: SCNVector3(
            cameraPose.position.x + targetDirection.x,
            cameraPose.position.y + targetDirection.y,
            cameraPose.position.z + targetDirection.z
        ))

        debugPrint("🎨 [PhotoAtPose] Position: \(planeNode.position), size: \(width)x\(height)")
        return planeNode
    }

    /// Create photo node mapped to nearest wall
    private static func createPhotoOnWall(image: UIImage, cameraPose: SpatialPose, walls: [WallSurface], photoIndex: Int) -> SCNNode {
        // Calculate camera forward direction
        let forward = cameraPose.orientation.act(SIMD3<Float>(0, 0, -1))

        // Find wall that camera is facing
        let targetWall = WallExtractor.findNearestWall(
            from: cameraPose.position,
            facing: forward,
            walls: walls
        )

        guard let wall = targetWall else {
            debugPrint("🎨 [PhotoOnWall] No suitable wall found, using pose position")
            return createPhotoAtPose(image: image, cameraPose: cameraPose)
        }

        // Calculate where camera ray intersects wall plane
        let rayOrigin = cameraPose.position
        let rayDirection = forward
        let planePoint = SIMD3<Float>(wall.position.x, wall.position.y, wall.position.z)
        let planeNormal = SIMD3<Float>(wall.normal.x, wall.normal.y, wall.normal.z)

        // Ray-plane intersection: t = dot(planePoint - rayOrigin, planeNormal) / dot(rayDirection, planeNormal)
        let denominator = dot(rayDirection, planeNormal)

        var intersectionPoint: SIMD3<Float>
        if abs(denominator) > 0.0001 {
            // Ray intersects plane
            let t = dot(planePoint - rayOrigin, planeNormal) / denominator
            intersectionPoint = rayOrigin + t * rayDirection
            debugPrint("🎨 [PhotoOnWall] Ray intersection at t=\(t), point=\(intersectionPoint)")
        } else {
            // Ray parallel to plane, use camera position projected onto wall
            let toWall = planePoint - rayOrigin
            let distanceToPlane = dot(toWall, planeNormal)
            intersectionPoint = rayOrigin + planeNormal * distanceToPlane
            debugPrint("🎨 [PhotoOnWall] Ray parallel to wall, projecting camera position")
        }

        debugPrint("🎨 [PhotoOnWall] Mapping photo to wall - intersection: \(intersectionPoint)")

        // Calculate photo dimensions
        let aspectRatio = image.size.width / image.size.height
        let height: CGFloat = min(2.0, wall.height * 0.8)  // Max 2m or 80% of wall
        let width = height * aspectRatio

        // Create plane
        let plane = SCNPlane(width: width, height: height)

        // Apply texture
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.lightingModel = .constant
        material.isDoubleSided = false
        material.transparency = 0.98  // Slightly transparent to see wall behind
        material.writesToDepthBuffer = true  // Ensure proper depth testing
        plane.materials = [material]

        let planeNode = SCNNode(geometry: plane)

        // Position photo at intersection point, slightly in front of wall
        // Add staggered offset to prevent z-fighting when photos overlap
        let baseOffset: Float = 0.05  // 5cm base distance from wall
        let stagger: Float = Float(photoIndex) * 0.001  // 1mm per photo index
        let totalOffset = baseOffset + stagger

        planeNode.position = SCNVector3(
            intersectionPoint.x + planeNormal.x * totalOffset,
            intersectionPoint.y,  // Use intersection Y (actual point on wall)
            intersectionPoint.z + planeNormal.z * totalOffset
        )

        // Orient to match wall (face outward from wall)
        // Point away from the wall surface
        planeNode.look(at: SCNVector3(
            intersectionPoint.x - planeNormal.x,
            intersectionPoint.y,
            intersectionPoint.z - planeNormal.z
        ))

        debugPrint("🎨 [PhotoOnWall] Photo #\(photoIndex): pos=\(planeNode.position), size=\(width)x\(height), offset=\(totalOffset)m, intersection=\(intersectionPoint)")
        return planeNode
    }
}
