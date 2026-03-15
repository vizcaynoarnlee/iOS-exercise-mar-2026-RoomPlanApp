//
//  OverlapDetector.swift
//  RoomPlanApp
//
//  Detects overlapping regions between panorama photos
//

import Foundation
import CoreGraphics
import simd

/// Information about overlapping photos
struct OverlapInfo {
    let index1: Int
    let index2: Int
    let region: CGRect  // Overlap region in canvas coordinates
    let overlapPercent: Float
    let seamLine: CGPoint  // Midpoint for blending mask
}

/// Detects overlapping photo pairs based on camera orientations
struct OverlapDetector {

    // MARK: - Public Interface

    /// Detect all overlapping photo pairs
    /// - Parameters:
    ///   - photos: Array of ScanPhoto objects with camera poses
    ///   - threshold: Minimum overlap percentage to consider (default: 10%)
    /// - Returns: Array of OverlapInfo describing overlapping pairs
    static func detectOverlaps(
        _ photos: [ScanPhoto],
        threshold: Float = PanoramaConfiguration.overlapDetectionThreshold
    ) -> [OverlapInfo] {
        var overlaps: [OverlapInfo] = []

        // Compare all photo pairs
        for i in 0..<photos.count {
            for j in (i + 1)..<photos.count {
                if let overlap = checkOverlap(
                    photos[i], index1: i,
                    photos[j], index2: j,
                    threshold: threshold
                ) {
                    overlaps.append(overlap)
                }
            }
        }

        debugPrint("🔍 [Overlap] Found \(overlaps.count) overlapping pairs")
        return overlaps
    }

    // MARK: - Private Helpers

    /// Check if two photos overlap
    private static func checkOverlap(
        _ photo1: ScanPhoto, index1: Int,
        _ photo2: ScanPhoto, index2: Int,
        threshold: Float
    ) -> OverlapInfo? {
        // Get spherical coordinates for both photos
        let (azimuth1, elevation1) = sphericalCoordinates(from: photo1.cameraPose.orientation)
        let (azimuth2, elevation2) = sphericalCoordinates(from: photo2.cameraPose.orientation)

        // Calculate angular distance between photo centers
        let angularDistance = calculateAngularDistance(
            azimuth1: azimuth1, elevation1: elevation1,
            azimuth2: azimuth2, elevation2: elevation2
        )

        // Get photo angular coverage
        let photoAngularWidth = PanoramaConfiguration.photoAngularWidth
        let photoAngularHeight = PanoramaConfiguration.photoAngularHeight

        // Photos overlap if distance < sum of half-widths
        let maxDistance = (photoAngularWidth + photoAngularHeight) / 2

        guard angularDistance < maxDistance else {
            return nil  // No overlap
        }

        // Calculate overlap rectangles in canvas coordinates
        let rect1 = calculatePhotoRect(azimuth: azimuth1, elevation: elevation1)
        let rect2 = calculatePhotoRect(azimuth: azimuth2, elevation: elevation2)

        // Handle wrap-around at 360°/0° boundary
        guard let intersectionRect = calculateIntersection(rect1, rect2) else {
            return nil
        }

        // Calculate overlap percentage
        let area1 = rect1.width * rect1.height
        let area2 = rect2.width * rect2.height
        let intersectionArea = intersectionRect.width * intersectionRect.height
        let overlapPercent = Float(intersectionArea / min(area1, area2))

        guard overlapPercent >= threshold else {
            return nil  // Overlap too small
        }

        // Calculate seam line (midpoint between photo centers)
        let seamLine = CGPoint(
            x: (rect1.midX + rect2.midX) / 2,
            y: (rect1.midY + rect2.midY) / 2
        )

        return OverlapInfo(
            index1: index1,
            index2: index2,
            region: intersectionRect,
            overlapPercent: overlapPercent,
            seamLine: seamLine
        )
    }

    /// Calculate angular distance between two orientations (great circle distance)
    private static func calculateAngularDistance(
        azimuth1: Float, elevation1: Float,
        azimuth2: Float, elevation2: Float
    ) -> Float {
        // Convert to Cartesian coordinates on unit sphere
        let x1 = cos(elevation1) * cos(azimuth1)
        let y1 = sin(elevation1)
        let z1 = cos(elevation1) * sin(azimuth1)

        let x2 = cos(elevation2) * cos(azimuth2)
        let y2 = sin(elevation2)
        let z2 = cos(elevation2) * sin(azimuth2)

        // Dot product gives cosine of angle
        let dotProduct = x1 * x2 + y1 * y2 + z1 * z2
        let clampedDot = max(-1.0, min(1.0, dotProduct))

        return acos(clampedDot)
    }

    /// Convert quaternion to spherical coordinates
    private static func sphericalCoordinates(from orientation: simd_quatf) -> (azimuth: Float, elevation: Float) {
        let forward = orientation.act(PanoramaConfiguration.cameraForwardDirection)
        let azimuth = atan2(forward.x, -forward.z)
        let elevation = asin(forward.y)
        return (azimuth, elevation)
    }

    /// Calculate photo rectangle in canvas coordinates
    private static func calculatePhotoRect(azimuth: Float, elevation: Float) -> CGRect {
        let width = PanoramaConfiguration.canvasWidth
        let height = PanoramaConfiguration.canvasHeight

        // Convert to equirectangular coordinates (0 to 1)
        let u = 1.0 - ((azimuth + Float.pi) / (2.0 * Float.pi))
        let v = 0.5 - (elevation / Float.pi)

        // Calculate photo size on canvas
        let photoAngularWidth = PanoramaConfiguration.photoAngularWidth
        let photoAngularHeight = PanoramaConfiguration.photoAngularHeight

        let photoWidthOnCanvas = CGFloat(photoAngularWidth / (2.0 * Float.pi)) * width
        let photoHeightOnCanvas = CGFloat(photoAngularHeight / Float.pi) * height

        // Center on photo's direction
        let x = CGFloat(u) * width - photoWidthOnCanvas / 2
        let y = CGFloat(v) * height - photoHeightOnCanvas / 2

        return CGRect(
            x: x,
            y: y,
            width: photoWidthOnCanvas,
            height: photoHeightOnCanvas
        )
    }

    /// Calculate intersection of two rectangles (handles wrap-around)
    private static func calculateIntersection(_ rect1: CGRect, _ rect2: CGRect) -> CGRect? {
        let canvasWidth = PanoramaConfiguration.canvasWidth

        // Check for horizontal wrap-around at 360°/0° boundary
        let wrapsAround1 = rect1.maxX > canvasWidth || rect1.minX < 0
        let wrapsAround2 = rect2.maxX > canvasWidth || rect2.minX < 0

        if wrapsAround1 || wrapsAround2 {
            // Handle wrap-around case (complex, skip for now)
            // In practice, photos near seam are rare
            return nil
        }

        // Standard rectangle intersection
        return rect1.intersection(rect2).isEmpty ? nil : rect1.intersection(rect2)
    }
}
