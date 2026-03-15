//
//  CIFeatureAligner.swift
//  RoomPlanApp
//
//  Feature-based image alignment using Core Image
//

import Foundation
import CoreImage
import UIKit
import simd

/// Simple CIFeature wrapper for detected corners
class SimpleCIFeature: CIFeature {
    private let _bounds: CGRect

    init(bounds: CGRect) {
        self._bounds = bounds
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var bounds: CGRect {
        return _bounds
    }
}

/// Handles feature detection and alignment correction
class CIFeatureAligner {

    // MARK: - Properties

    private let context: CIContext

    // MARK: - Initialization

    init() {
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    // MARK: - Public Interface

    /// Find feature matches between photo pairs for bundle adjustment
    /// - Parameters:
    ///   - photoIndex1: Index of first photo
    ///   - photoIndex2: Index of second photo
    ///   - photo1: First photo
    ///   - photo2: Second photo
    /// - Returns: Array of matched feature points
    func findMatches(
        photoIndex1: Int,
        photoIndex2: Int,
        photo1: ScanPhoto,
        photo2: ScanPhoto
    ) -> [(point1: CGPoint, point2: CGPoint)] {
        // Load full images
        guard let image1 = loadImage(from: photo1.imageURL),
              let image2 = loadImage(from: photo2.imageURL) else {
            return []
        }

        // Detect features in full images
        let features1 = detectFeatures(in: image1)
        let features2 = detectFeatures(in: image2)

        guard !features1.isEmpty && !features2.isEmpty else {
            return []
        }

        // Match features using cross-check matching
        let matches = matchFeatures(features1: features1, features2: features2, image1: image1, image2: image2)

        return matches
    }


    // MARK: - Feature Detection

    /// Detect corner features in image using Harris corner detection
    private func detectFeatures(in image: UIImage) -> [CIFeature] {
        // Use grid-based sampling approach for robustness
        let corners = detectCornersGridSampling(in: image)

        // Convert CGPoints to simple CIFeature wrapper
        return corners.map { point in
            SimpleCIFeature(bounds: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
        }
    }

    /// Detect corners using grid-based intensity sampling (robust for room photos)
    private func detectCornersGridSampling(in image: UIImage) -> [CGPoint] {
        guard let cgImage = image.cgImage else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create bitmap context to sample pixels
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return []
        }

        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Sample grid of points (dense grid for full image coverage)
        var corners: [CGPoint] = []
        let gridSize = 30  // Increased for full images
        let stepX = width / gridSize
        let stepY = height / gridSize

        for i in 1..<gridSize {  // Skip borders
            for j in 1..<gridSize {
                let x = i * stepX
                let y = j * stepY

                // Check if this point is a corner (has high gradient)
                if isCornerPoint(x: x, y: y, width: width, pixels: pixels) {
                    corners.append(CGPoint(x: x, y: y))
                }
            }
        }

        debugPrint("✅ [Features] Detected \(corners.count) grid corners")
        return corners
    }

    /// Check if point has high gradient (corner-like)
    private func isCornerPoint(x: Int, y: Int, width: Int, pixels: UnsafeMutablePointer<UInt8>) -> Bool {
        let offset = (y * width + x) * 4

        guard x > 0, y > 0, x < width - 1 else {
            return false
        }

        // Sample center pixel
        let centerR = Float(pixels[offset])
        let centerG = Float(pixels[offset + 1])
        let centerB = Float(pixels[offset + 2])
        let centerIntensity = (centerR + centerG + centerB) / 3.0

        // Sample neighbors (8-connected)
        let neighbors = [
            (-1, -1), (0, -1), (1, -1),
            (-1,  0),          (1,  0),
            (-1,  1), (0,  1), (1,  1)
        ]

        var totalDiff: Float = 0

        for (dx, dy) in neighbors {
            let nx = x + dx
            let ny = y + dy
            let nOffset = (ny * width + nx) * 4

            let nR = Float(pixels[nOffset])
            let nG = Float(pixels[nOffset + 1])
            let nB = Float(pixels[nOffset + 2])
            let nIntensity = (nR + nG + nB) / 3.0

            totalDiff += abs(centerIntensity - nIntensity)
        }

        let avgDiff = totalDiff / 8.0

        // Threshold: points with high average difference are corners/edges
        return avgDiff > 10.0  // Lowered threshold for more features
    }

    // MARK: - Feature Matching

    /// Enhanced descriptor with intensity + gradient (simplified SIFT-like)
    private struct FeatureDescriptor {
        let position: CGPoint
        let intensities: [Float]  // Raw intensity values
        let gradients: [Float]    // Gradient magnitudes
        let validPixels: Int

        init(position: CGPoint, image: CIImage, context: CIContext) {
            self.position = position

            // Extract 16x16 patch around position (larger for better discrimination)
            let patchSize: CGFloat = 16
            let patchRect = CGRect(
                x: position.x - patchSize / 2,
                y: position.y - patchSize / 2,
                width: patchSize,
                height: patchSize
            )

            // Ensure patch is within image bounds
            let clampedRect = patchRect.intersection(image.extent)

            var intensityValues: [Float] = []
            var gradientValues: [Float] = []

            if clampedRect.width > 0 && clampedRect.height > 0,
               let cgImage = context.createCGImage(image, from: clampedRect),
               let dataProvider = cgImage.dataProvider,
               let data = dataProvider.data,
               let bytes = CFDataGetBytePtr(data) {

                let width = cgImage.width
                let height = cgImage.height
                let bytesPerRow = cgImage.bytesPerRow

                // Extract intensities
                var intensityGrid: [[Float]] = Array(repeating: Array(repeating: 0, count: width), count: height)

                for y in 0..<height {
                    for x in 0..<width {
                        let offset = y * bytesPerRow + x * 4
                        let r = Float(bytes[offset])
                        let g = Float(bytes[offset + 1])
                        let b = Float(bytes[offset + 2])
                        let intensity = (r + g + b) / (3.0 * 255.0)
                        intensityGrid[y][x] = intensity
                        intensityValues.append(intensity)
                    }
                }

                // Compute gradients (Sobel-like)
                for y in 1..<(height-1) {
                    for x in 1..<(width-1) {
                        let gx = intensityGrid[y][x+1] - intensityGrid[y][x-1]
                        let gy = intensityGrid[y+1][x] - intensityGrid[y-1][x]
                        let magnitude = sqrt(gx * gx + gy * gy)
                        gradientValues.append(magnitude)
                    }
                }
            }

            self.intensities = intensityValues
            self.gradients = gradientValues
            self.validPixels = intensityValues.count
        }

        /// Calculate descriptor distance (intensity + gradient)
        func distance(to other: FeatureDescriptor) -> Float {
            guard validPixels > 0 && other.validPixels > 0 else {
                return .infinity
            }

            let minIntensityCount = min(intensities.count, other.intensities.count)
            let minGradientCount = min(gradients.count, other.gradients.count)

            guard minIntensityCount > 0 && minGradientCount > 0 else {
                return .infinity
            }

            // Intensity distance
            var intensityDist: Float = 0
            for i in 0..<minIntensityCount {
                let diff = intensities[i] - other.intensities[i]
                intensityDist += diff * diff
            }
            intensityDist = sqrt(intensityDist / Float(minIntensityCount))

            // Gradient distance
            var gradientDist: Float = 0
            for i in 0..<minGradientCount {
                let diff = gradients[i] - other.gradients[i]
                gradientDist += diff * diff
            }
            gradientDist = sqrt(gradientDist / Float(minGradientCount))

            // Combined distance (weighted average)
            return 0.5 * intensityDist + 0.5 * gradientDist
        }
    }

    /// Match features between two images using CROSS-CHECK matching (mutual nearest neighbors)
    private func matchFeatures(features1: [CIFeature], features2: [CIFeature],
                              image1: UIImage, image2: UIImage) -> [(CGPoint, CGPoint)] {
        // Convert UIImages to CIImages for descriptor extraction
        guard let ciImage1 = CIImage(image: image1),
              let ciImage2 = CIImage(image: image2) else {
            debugPrint("⚠️ [Match] Failed to convert UIImages to CIImages")
            return []
        }

        // Create descriptors for all features in both images
        let descriptors1 = features1.map { feature in
            FeatureDescriptor(position: CGPoint(x: feature.bounds.midX, y: feature.bounds.midY),
                            image: ciImage1, context: context)
        }

        let descriptors2 = features2.map { feature in
            FeatureDescriptor(position: CGPoint(x: feature.bounds.midX, y: feature.bounds.midY),
                            image: ciImage2, context: context)
        }

        // Position search radius (relaxed - RANSAC will filter outliers)
        let maxPositionDistance: CGFloat = 200.0
        let maxDistance: Float = 0.6  // Descriptor distance threshold

        // Step 1: Match 1→2 (forward matches)
        var forward: [(Int, Int, Float)] = []  // (index1, index2, distance)

        for (i, desc1) in descriptors1.enumerated() {
            var bestIdx = -1
            var bestDist: Float = .infinity

            for (j, desc2) in descriptors2.enumerated() {
                // Position constraint
                let dx = desc1.position.x - desc2.position.x
                let dy = desc1.position.y - desc2.position.y
                let posDistance = sqrt(dx * dx + dy * dy)
                if posDistance > maxPositionDistance { continue }

                let dist = desc1.distance(to: desc2)
                if dist < bestDist && dist < maxDistance {
                    bestDist = dist
                    bestIdx = j
                }
            }

            if bestIdx >= 0 {
                forward.append((i, bestIdx, bestDist))
            }
        }

        // Step 2: Match 2→1 (backward matches)
        var backward: [(Int, Int, Float)] = []  // (index2, index1, distance)

        for (j, desc2) in descriptors2.enumerated() {
            var bestIdx = -1
            var bestDist: Float = .infinity

            for (i, desc1) in descriptors1.enumerated() {
                // Position constraint
                let dx = desc1.position.x - desc2.position.x
                let dy = desc1.position.y - desc2.position.y
                let posDistance = sqrt(dx * dx + dy * dy)
                if posDistance > maxPositionDistance { continue }

                let dist = desc1.distance(to: desc2)
                if dist < bestDist && dist < maxDistance {
                    bestDist = dist
                    bestIdx = i
                }
            }

            if bestIdx >= 0 {
                backward.append((j, bestIdx, bestDist))
            }
        }

        // Step 3: Cross-check - only accept mutual matches
        var matches: [(CGPoint, CGPoint)] = []
        var minDistanceSeen: Float = .infinity
        var maxDistanceSeen: Float = 0

        for (i1, j1, dist1) in forward {
            // Check if j1 matches back to i1
            for (j2, i2, _) in backward {
                if i1 == i2 && j1 == j2 {
                    // Mutual match found!
                    matches.append((descriptors1[i1].position, descriptors2[j1].position))
                    minDistanceSeen = min(minDistanceSeen, dist1)
                    maxDistanceSeen = max(maxDistanceSeen, dist1)
                    break
                }
            }
        }

        debugPrint("✅ [Match] Found \(matches.count) cross-checked matches (dist: \(minDistanceSeen)-\(maxDistanceSeen))")
        return matches
    }


    // MARK: - Image Processing

    /// Load UIImage from URL
    private func loadImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

}
