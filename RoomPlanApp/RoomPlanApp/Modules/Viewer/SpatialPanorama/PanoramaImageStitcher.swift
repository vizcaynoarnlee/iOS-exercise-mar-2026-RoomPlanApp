//
//  PanoramaImageStitcher.swift
//  RoomPlanApp
//
//  Handles stitching individual photos into equirectangular panorama
//

import Foundation
import UIKit
import simd

/// Responsible for creating equirectangular panorama images from individual photos
struct PanoramaImageStitcher {

    // MARK: - Properties

    /// Progress callback type: (description, progress 0-1)
    typealias ProgressCallback = (String, Float) -> Void

    /// Cached adaptive void color (to avoid recalculating)
    private static var cachedVoidColor: (photos: [URL], color: UIColor)?

    // MARK: - Public Interface

    /// Get appropriate void fill color (adaptive or static)
    /// - Parameter photos: Array of ScanPhoto objects
    /// - Returns: UIColor to use for void fill
    static func getVoidFillColor(for photos: [ScanPhoto]) -> UIColor {
        guard PanoramaConfiguration.useAdaptiveVoidColor else {
            return PanoramaConfiguration.voidFillColor
        }

        let imageURLs = photos.map { $0.imageURL }

        // Check cache
        if let cached = cachedVoidColor,
           cached.photos == imageURLs {
            return cached.color
        }

        // Extract dominant color
        if let dominantColor = DominantColorExtractor.extractDominantColor(
            from: imageURLs,
            sampleSize: PanoramaConfiguration.colorSampleCount
        ) {
            // Cache for reuse
            cachedVoidColor = (photos: imageURLs, color: dominantColor)
            return dominantColor
        }

        // Fallback
        return PanoramaConfiguration.voidFillColor
    }

    /// Create equirectangular panorama image from individual photos
    /// - Parameters:
    ///   - photos: Array of ScanPhoto objects with camera poses
    ///   - progress: Optional progress callback
    /// - Returns: Stitched UIImage in equirectangular format, or nil if failed
    static func createEquirectangularImage(
        from photos: [ScanPhoto],
        progress: ProgressCallback? = nil
    ) -> UIImage? {
        progress?("Preparing panorama...", 0.0)
        let width = PanoramaConfiguration.canvasWidth
        let height = PanoramaConfiguration.canvasHeight
        let size = CGSize(width: width, height: height)

        // Determine void fill color (adaptive or static)
        if PanoramaConfiguration.useAdaptiveVoidColor {
            progress?("Analyzing colors...", 0.05)
        }
        let voidColor = getVoidFillColor(for: photos)

        // Create graphics context
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }  // Always cleanup

        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        // Fill voids with determined background color
        context.setFillColor(voidColor.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Phase 1: Detect overlapping photo pairs
        progress?("Detecting overlaps...", 0.1)
        let overlaps = OverlapDetector.detectOverlaps(photos)

        // Phase 2: Refine camera poses using bundle adjustment (if enabled)
        progress?("Refining camera poses...", 0.2)
        var refinedPhotos = photos

        if PanoramaConfiguration.usePoseRefinement && !overlaps.isEmpty {
            let aligner = CIFeatureAligner()
            var allMatches: [SphericalBundleAdjuster.FeatureMatch] = []

            // Collect feature matches from all overlapping pairs
            progress?("Finding feature matches...", 0.25)
            for overlap in overlaps {
                let matches = aligner.findMatches(
                    photoIndex1: overlap.index1,
                    photoIndex2: overlap.index2,
                    photo1: photos[overlap.index1],
                    photo2: photos[overlap.index2]
                )

                // Convert to bundle adjustment format
                for match in matches {
                    allMatches.append(SphericalBundleAdjuster.FeatureMatch(
                        photoIndex1: overlap.index1,
                        photoIndex2: overlap.index2,
                        point1: match.point1,
                        point2: match.point2
                    ))
                }
            }

            // Run bundle adjustment
            if !allMatches.isEmpty {
                progress?("Optimizing camera orientations...", 0.3)
                let adjuster = SphericalBundleAdjuster()
                refinedPhotos = adjuster.refinePoses(photos: photos, matches: allMatches)
            } else {
                debugPrint("⚠️ [Stitch] No feature matches found, using original poses")
            }
        }

        // Phase 3: Apply gain compensation (if enabled)
        progress?("Normalizing exposure...", 0.35)
        var normalizedPhotos = refinedPhotos

        if PanoramaConfiguration.useGainCompensation {
            let compensator = CIGainCompensator()
            let gainMaps = compensator.calculateGainMaps(photos: refinedPhotos, overlaps: overlaps)

            normalizedPhotos = photos.enumerated().map { index, photo in
                var photo = photo
                if let gain = gainMaps[index], gain != 1.0 {
                    if let imageData = try? Data(contentsOf: photo.imageURL),
                       let image = UIImage(data: imageData) {
                        let adjusted = compensator.applyGain(image, gain: gain)

                        // Save adjusted image temporarily
                        if let adjustedData = adjusted.jpegData(compressionQuality: 0.95) {
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent("gain_\(index).jpg")
                            try? adjustedData.write(to: tempURL)
                            photo.imageURL = tempURL
                        }
                    }
                }
                return photo
            }
        }

        // Phase 4: Initialize Metal blender (if enabled)
        progress?("Preparing blending...", 0.45)
        var metalBlender: MetalPyramidBlender?
        if PanoramaConfiguration.useMultiBandBlending {
            metalBlender = MetalPyramidBlender()
            if metalBlender == nil {
                debugPrint("⚠️ [Stitch] Metal blender unavailable, using simple blending")
            }
        }

        // Phase 5: Project each photo onto equirectangular canvas
        progress?("Blending photos...", 0.5)
        var failedPhotos = 0
        for (index, photo) in normalizedPhotos.enumerated() {
            // Update progress
            let photoProgress = 0.5 + (0.45 * Float(index) / Float(normalizedPhotos.count))
            progress?("Blending photo \(index + 1)/\(normalizedPhotos.count)...", photoProgress)

            // Load image
            guard let imageData = try? Data(contentsOf: photo.imageURL),
                  let image = UIImage(data: imageData),
                  let cgImage = image.cgImage else {
                failedPhotos += 1
                debugPrint("🌐 [Stitch] ⚠️ Failed to load photo #\(index + 1)")
                continue
            }

            // Get spherical coordinates from camera orientation
            let (azimuth, elevation) = sphericalCoordinates(from: photo.cameraPose.orientation)

            // Convert to equirectangular coordinates (0 to 1)
            // Azimuth: -π to π → 1 to 0 (reversed for inside sphere view)
            // Elevation: π/2 to -π/2 → 0 to 1 (top to bottom)
            let u = 1.0 - ((azimuth + Float.pi) / (2.0 * Float.pi))  // 0 to 1 (flipped)
            let v = 0.5 - (elevation / Float.pi)  // 0 to 1 (inverted)

            // Calculate photo size on canvas
            let photoAngularWidth = PanoramaConfiguration.photoAngularWidth
            let photoAngularHeight = PanoramaConfiguration.photoAngularHeight

            let photoWidthOnCanvas = CGFloat(photoAngularWidth / (2.0 * Float.pi)) * width
            let photoHeightOnCanvas = CGFloat(photoAngularHeight / Float.pi) * height

            // Calculate position (centered on the photo's direction)
            let x = CGFloat(u) * width - photoWidthOnCanvas / 2
            let y = CGFloat(v) * height - photoHeightOnCanvas / 2

            // Calculate destination rectangle
            let destRect = CGRect(
                x: x,
                y: y,
                width: photoWidthOnCanvas,
                height: photoHeightOnCanvas
            )

            // Photos are positioned using refined camera poses (bundle adjustment)
            // No image warping - spherical projection handles alignment

            // Draw photo on canvas with proper orientation
            if PanoramaConfiguration.useSeamSoftening {
                drawFlippedImageWithSeamSoftening(cgImage, in: destRect, context: context)
            } else {
                drawFlippedImage(cgImage, in: destRect, context: context)
            }

            debugPrint("🌐 [Stitch] Photo #\(index + 1) at (\(Int(u * 100))%, \(Int(v * 100))%)")
        }

        if failedPhotos > 0 {
            debugPrint("🌐 [Stitch] ⚠️ Failed to load \(failedPhotos)/\(photos.count) photos")
        }

        progress?("Finalizing panorama...", 0.95)

        guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }

        progress?("Complete", 1.0)
        return finalImage
    }

    // MARK: - Private Helpers

    /// Convert quaternion camera orientation to spherical coordinates
    /// - Parameter orientation: Camera orientation as quaternion
    /// - Returns: Tuple of (azimuth, elevation) in radians
    private static func sphericalCoordinates(from orientation: simd_quatf) -> (azimuth: Float, elevation: Float) {
        // Get forward direction vector from quaternion
        // Camera looks along -Z axis in local space
        let forward = orientation.act(PanoramaConfiguration.cameraForwardDirection)

        // Calculate azimuth (horizontal angle) - rotation around Y axis
        // atan2(x, z) gives angle in XZ plane, range: -π to π
        let azimuth = atan2(forward.x, -forward.z)

        // Calculate elevation (vertical angle) - angle from horizontal plane
        // asin(y) gives vertical angle, range: -π/2 to π/2
        let elevation = asin(forward.y)

        return (azimuth, elevation)
    }

    /// Draw image flipped both horizontally and vertically for inside sphere viewing
    /// - Parameters:
    ///   - cgImage: The CGImage to draw
    ///   - rect: Destination rectangle
    ///   - context: Graphics context
    private static func drawFlippedImage(_ cgImage: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()

        // Translate to center of destination rect
        context.translateBy(x: rect.midX, y: rect.midY)

        // Flip both horizontally and vertically (for inside sphere viewing)
        context.scaleBy(x: -1.0, y: -1.0)

        // Translate back
        context.translateBy(x: -rect.midX, y: -rect.midY)

        context.draw(cgImage, in: rect)

        context.restoreGState()
    }

    /// Draw image with subtle edge softening for smooth seams (no ghosting)
    /// - Parameters:
    ///   - cgImage: The CGImage to draw
    ///   - rect: Destination rectangle
    ///   - context: Graphics context
    private static func drawFlippedImageWithSeamSoftening(_ cgImage: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()

        // Use very small feather (just a few pixels) instead of percentage
        let featherPixels = PanoramaConfiguration.seamFeatherPixels

        // Create a temporary layer to draw the image with mask
        context.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)

        // Translate to center of destination rect
        context.translateBy(x: rect.midX, y: rect.midY)

        // Flip both horizontally and vertically (for inside sphere viewing)
        context.scaleBy(x: -1.0, y: -1.0)

        // Translate back
        context.translateBy(x: -rect.midX, y: -rect.midY)

        // Draw the image
        context.draw(cgImage, in: rect)

        // Create gradient mask to soften edges (just a few pixels)
        context.setBlendMode(.destinationIn)

        // Draw very subtle gradient on edges
        drawSeamSofteningGradient(in: rect, featherPixels: featherPixels, context: context)

        context.endTransparencyLayer()
        context.restoreGState()
    }

    /// Draw very subtle gradient softening on edges (pixel-based, not percentage)
    private static func drawSeamSofteningGradient(in rect: CGRect, featherPixels: CGFloat, context: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let transparent = UIColor.clear.cgColor
        let opaque = UIColor.white.cgColor

        // Use more gradient steps for smoother transition
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        let midOpaque = UIColor(white: 1.0, alpha: 0.7).cgColor

        // Left edge - very thin horizontal gradient
        if featherPixels > 0 {
            let leftRect = CGRect(x: rect.minX, y: rect.minY, width: featherPixels, height: rect.height)
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: [transparent, midOpaque, opaque] as CFArray, locations: locations) {
                context.drawLinearGradient(gradient,
                                          start: CGPoint(x: leftRect.minX, y: leftRect.midY),
                                          end: CGPoint(x: leftRect.maxX, y: leftRect.midY),
                                          options: [])
            }

            // Right edge - very thin horizontal gradient
            let rightRect = CGRect(x: rect.maxX - featherPixels, y: rect.minY, width: featherPixels, height: rect.height)
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: [opaque, midOpaque, transparent] as CFArray, locations: locations) {
                context.drawLinearGradient(gradient,
                                          start: CGPoint(x: rightRect.minX, y: rightRect.midY),
                                          end: CGPoint(x: rightRect.maxX, y: rightRect.midY),
                                          options: [])
            }

            // Top edge - very thin vertical gradient
            let topRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: featherPixels)
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: [transparent, midOpaque, opaque] as CFArray, locations: locations) {
                context.drawLinearGradient(gradient,
                                          start: CGPoint(x: topRect.midX, y: topRect.minY),
                                          end: CGPoint(x: topRect.midX, y: topRect.maxY),
                                          options: [])
            }

            // Bottom edge - very thin vertical gradient
            let bottomRect = CGRect(x: rect.minX, y: rect.maxY - featherPixels, width: rect.width, height: featherPixels)
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: [opaque, midOpaque, transparent] as CFArray, locations: locations) {
                context.drawLinearGradient(gradient,
                                          start: CGPoint(x: bottomRect.midX, y: bottomRect.minY),
                                          end: CGPoint(x: bottomRect.midX, y: bottomRect.maxY),
                                          options: [])
            }
        }
    }
}
