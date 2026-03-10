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

    // MARK: - Public Interface

    /// Create equirectangular panorama image from individual photos
    /// - Parameter photos: Array of ScanPhoto objects with camera poses
    /// - Returns: Stitched UIImage in equirectangular format, or nil if failed
    static func createEquirectangularImage(from photos: [ScanPhoto]) -> UIImage? {
        let width = PanoramaConfiguration.canvasWidth
        let height = PanoramaConfiguration.canvasHeight
        let size = CGSize(width: width, height: height)

        // Create graphics context
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }  // Always cleanup

        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        // Fill with black background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Project each photo onto equirectangular canvas
        var failedPhotos = 0
        for (index, photo) in photos.enumerated() {
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

            // Draw photo on canvas with proper orientation
            let destRect = CGRect(
                x: x,
                y: y,
                width: photoWidthOnCanvas,
                height: photoHeightOnCanvas
            )

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

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Private Helpers

    /// Convert quaternion camera orientation to spherical coordinates
    /// - Parameter orientation: Camera orientation as quaternion
    /// - Returns: Tuple of (azimuth, elevation) in radians
    private static func sphericalCoordinates(from orientation: simd_quatf) -> (azimuth: Float, elevation: Float) {
        // Get forward direction vector from quaternion
        // Camera looks along -Z axis in local space
        let forward = orientation.act(SIMD3<Float>(0, 0, -1))

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
