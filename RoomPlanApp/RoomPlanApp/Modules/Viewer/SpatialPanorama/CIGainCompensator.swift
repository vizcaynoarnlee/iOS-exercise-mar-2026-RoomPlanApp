//
//  CIGainCompensator.swift
//  RoomPlanApp
//
//  Exposure and color normalization using Core Image
//

import Foundation
import CoreImage
import UIKit

/// Handles exposure and color gain compensation across photos
class CIGainCompensator {

    // MARK: - Properties

    private let context: CIContext

    // MARK: - Initialization

    init() {
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    // MARK: - Public Interface

    /// Calculate gain adjustments for all photos based on overlaps
    /// - Parameters:
    ///   - photos: Array of scan photos
    ///   - overlaps: Detected overlap regions
    /// - Returns: Dictionary mapping photo index to gain multiplier
    func calculateGainMaps(photos: [ScanPhoto], overlaps: [OverlapInfo]) -> [Int: Float] {
        var gainMap: [Int: Float] = [:]

        // Initialize all gains to 1.0
        for i in 0..<photos.count {
            gainMap[i] = 1.0
        }

        guard !overlaps.isEmpty else {
            debugPrint("🎨 [Gain] No overlaps, no compensation needed")
            return gainMap
        }

        // Calculate reference intensity (use first photo as reference)
        guard let referenceImage = loadImage(from: photos[0].imageURL) else {
            debugPrint("⚠️ [Gain] Failed to load reference image")
            return gainMap
        }

        let referenceIntensity = calculateMeanIntensity(referenceImage)

        // Calculate gain for each photo relative to reference
        for (index, photo) in photos.enumerated() {
            if index == 0 {
                continue  // Reference photo has gain = 1.0
            }

            guard let image = loadImage(from: photo.imageURL) else {
                debugPrint("⚠️ [Gain] Failed to load image for photo \(index)")
                continue
            }

            let intensity = calculateMeanIntensity(image)

            // Calculate gain to match reference
            let gain = intensity > 0 ? referenceIntensity / intensity : 1.0

            // Clamp gain to reasonable range (prevent over/under exposure)
            gainMap[index] = clamp(
                gain,
                min: PanoramaConfiguration.minGainMultiplier,
                max: PanoramaConfiguration.maxGainMultiplier
            )
        }

        debugPrint("🎨 [Gain] Calculated gains for \(photos.count) photos")
        return gainMap
    }

    /// Apply gain adjustment to image
    /// - Parameters:
    ///   - image: Input image
    ///   - gain: Gain multiplier (1.0 = no change)
    /// - Returns: Adjusted image
    func applyGain(_ image: UIImage, gain: Float) -> UIImage {
        guard gain != 1.0, let ciImage = CIImage(image: image) else {
            return image  // No adjustment needed
        }

        // Use CIExposureAdjust to adjust brightness
        guard let filter = CIFilter(name: "CIExposureAdjust") else {
            debugPrint("⚠️ [Gain] Failed to create CIExposureAdjust filter")
            return image
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(log2(gain), forKey: kCIInputEVKey)

        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Private Helpers

    /// Calculate mean intensity of image using Core Image
    private func calculateMeanIntensity(_ image: UIImage) -> Float {
        guard let ciImage = CIImage(image: image) else {
            return 1.0
        }

        // Use CIAreaAverage to get mean color
        guard let filter = CIFilter(name: "CIAreaAverage") else {
            debugPrint("⚠️ [Gain] Failed to create CIAreaAverage filter")
            return 1.0
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else {
            return 1.0
        }

        // Extract single pixel with average color
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Calculate luminance (grayscale intensity)
        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0

        // Weighted luminance (ITU-R BT.601 standard)
        return PanoramaConfiguration.luminanceWeightRed * r +
               PanoramaConfiguration.luminanceWeightGreen * g +
               PanoramaConfiguration.luminanceWeightBlue * b
    }

    /// Load UIImage from URL
    private func loadImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    /// Clamp value to range
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.min(Swift.max(value, min), max)
    }
}
