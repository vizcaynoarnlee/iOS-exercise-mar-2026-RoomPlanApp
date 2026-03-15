//
//  SphericalBundleAdjuster.swift
//  RoomPlanApp
//
//  Bundle adjustment for refining camera poses in spherical panoramas
//

import Foundation
import simd

/// Refines camera orientations using feature matches in spherical space
class SphericalBundleAdjuster {

    // MARK: - Types

    /// Feature match between two photos
    struct FeatureMatch {
        let photoIndex1: Int
        let photoIndex2: Int
        let point1: CGPoint  // In image coordinates
        let point2: CGPoint  // In image coordinates
    }

    // MARK: - Public Interface

    /// Refine camera poses using feature matches
    /// - Parameters:
    ///   - photos: Array of photos with initial poses
    ///   - matches: Feature correspondences between photo pairs
    /// - Returns: Updated photos with refined orientations
    func refinePoses(photos: [ScanPhoto], matches: [FeatureMatch]) -> [ScanPhoto] {
        guard matches.count >= PanoramaConfiguration.minFeaturesForRefinement else {
            debugPrint("⚠️ [BundleAdj] Insufficient matches (\(matches.count)), skipping refinement")
            return photos
        }

        var refinedPhotos = photos
        let iterations = PanoramaConfiguration.bundleAdjustmentIterations

        debugPrint("🔧 [BundleAdj] Starting with \(matches.count) feature matches")

        // Iterative optimization
        for iteration in 0..<iterations {
            var totalError: Float = 0
            var adjustments: [Int: simd_quatf] = [:]

            // Calculate rotation adjustments for each photo
            for match in matches {
                let photo1 = refinedPhotos[match.photoIndex1]
                let photo2 = refinedPhotos[match.photoIndex2]

                // Project feature points to sphere using camera orientations
                let imageSize = CGSize(
                    width: PanoramaConfiguration.defaultImageWidth,
                    height: PanoramaConfiguration.defaultImageHeight
                )

                let spherePoint1 = projectToSphere(
                    imagePoint: match.point1,
                    imageSize: imageSize,
                    orientation: photo1.cameraPose.orientation
                )

                let spherePoint2 = projectToSphere(
                    imagePoint: match.point2,
                    imageSize: imageSize,
                    orientation: photo2.cameraPose.orientation
                )

                // Calculate reprojection error (angular distance on sphere)
                let error = angularDistance(spherePoint1, spherePoint2)
                totalError += error

                // Calculate small rotation to align points
                if error > PanoramaConfiguration.minErrorForAdjustment {
                    let adjustment = calculateRotationAdjustment(
                        from: spherePoint2,
                        to: spherePoint1,
                        maxRotation: PanoramaConfiguration.maxRotationAdjustment
                    )

                    // Accumulate adjustment for photo2
                    if let existing = adjustments[match.photoIndex2] {
                        let factor = PanoramaConfiguration.adjustmentInterpolationFactor
                        adjustments[match.photoIndex2] = simd_slerp(existing, adjustment, factor)
                    } else {
                        adjustments[match.photoIndex2] = adjustment
                    }
                }
            }

            // Apply adjustments
            var numAdjusted = 0
            for (photoIndex, adjustment) in adjustments {
                let currentOrientation = refinedPhotos[photoIndex].cameraPose.orientation
                let newOrientation = simd_normalize(adjustment * currentOrientation)

                refinedPhotos[photoIndex].cameraPose.orientation = newOrientation
                numAdjusted += 1
            }

            let avgError = totalError / Float(matches.count)

            // Log progress periodically
            let logFrequency = PanoramaConfiguration.loggingFrequency
            if iteration % logFrequency == 0 || iteration == iterations - 1 {
                debugPrint("🔧 [BundleAdj] Iter \(iteration+1): avgError=\(String(format: "%.4f", avgError))° adjusted=\(numAdjusted) photos")
            }

            // Early stopping if converged
            if avgError < PanoramaConfiguration.convergenceThreshold {
                debugPrint("✅ [BundleAdj] Converged at iteration \(iteration+1)")
                break
            }
        }

        debugPrint("✅ [BundleAdj] Refinement complete")
        return refinedPhotos
    }

    // MARK: - Projection Functions

    /// Project image point to unit sphere using camera orientation
    private func projectToSphere(
        imagePoint: CGPoint,
        imageSize: CGSize,
        orientation: simd_quatf
    ) -> SIMD3<Float> {
        // Normalize image coordinates to [-1, 1]
        let x = Float((imagePoint.x / imageSize.width) * 2.0 - 1.0)
        let y = Float((imagePoint.y / imageSize.height) * 2.0 - 1.0)

        // Calculate focal length from field of view
        let fov: Float = PanoramaConfiguration.captureFieldOfView * .pi / 180.0
        let focalLength = 1.0 / tan(fov / 2.0)

        // Ray direction in camera space (looking down -Z)
        let rayCamera = simd_normalize(SIMD3<Float>(x / focalLength, y / focalLength, -1.0))

        // Rotate to world space using camera orientation
        let rayWorld = orientation.act(rayCamera)

        return simd_normalize(rayWorld)
    }

    /// Calculate angular distance between two points on unit sphere (in radians)
    private func angularDistance(_ p1: SIMD3<Float>, _ p2: SIMD3<Float>) -> Float {
        let dot = simd_dot(p1, p2)
        let clampedDot = max(-1.0, min(1.0, dot))  // Clamp to avoid numerical issues
        return acos(clampedDot)
    }

    /// Calculate rotation quaternion to align two sphere points
    private func calculateRotationAdjustment(
        from: SIMD3<Float>,
        to: SIMD3<Float>,
        maxRotation: Float
    ) -> simd_quatf {
        // Calculate rotation axis (cross product)
        let axis = simd_cross(from, to)
        let axisLength = simd_length(axis)

        // If points are too close, no rotation needed
        if axisLength < PanoramaConfiguration.minAxisLength {
            return PanoramaConfiguration.identityQuaternion
        }

        let normalizedAxis = axis / axisLength

        // Calculate rotation angle
        var angle = angularDistance(from, to)

        // Limit rotation magnitude
        angle = min(angle, maxRotation)

        // Create quaternion from axis-angle
        return simd_quatf(angle: angle, axis: normalizedAxis)
    }
}
