//
//  DominantColorExtractor.swift
//  RoomPlanApp
//
//  Extracts dominant color from images for adaptive void fill
//

import UIKit
import CoreImage

/// Extracts dominant color from images using color quantization
struct DominantColorExtractor {

    // MARK: - Public Interface

    /// Extract dominant color from multiple images
    /// - Parameters:
    ///   - imageURLs: Array of image URLs to analyze
    ///   - sampleSize: Number of images to sample (default: all)
    /// - Returns: Dominant UIColor or nil if extraction fails
    static func extractDominantColor(
        from imageURLs: [URL],
        sampleSize: Int? = nil
    ) -> UIColor? {
        let samplesToUse = sampleSize ?? imageURLs.count
        let step = max(1, imageURLs.count / samplesToUse)

        var allColors: [(color: UIColor, count: Int)] = []

        // Sample images
        for (index, url) in imageURLs.enumerated() where index % step == 0 {
            guard let image = loadImage(from: url),
                  let resized = resizeImage(image, maxDimension: 100) else {
                continue
            }

            if let colors = extractColors(from: resized) {
                allColors.append(contentsOf: colors)
            }
        }

        guard !allColors.isEmpty else {
            debugPrint("⚠️ [DominantColor] No colors extracted, using fallback")
            return nil
        }

        // Combine similar colors
        let dominantColor = findDominantColor(from: allColors)

        debugPrint("✅ [DominantColor] Extracted dominant color: \(colorDescription(dominantColor))")
        return dominantColor
    }

    // MARK: - Private Helpers

    /// Load image from URL
    private static func loadImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    /// Resize image for faster processing
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let aspectRatio = size.width / size.height

        let newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Extract color histogram from image
    private static func extractColors(from image: UIImage) -> [(color: UIColor, count: Int)]? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Create bitmap context
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Color buckets (quantize to reduce color space)
        var colorCounts: [String: (color: UIColor, count: Int)] = [:]

        // Sample pixels (skip some for performance)
        let step = 4  // Sample every 4th pixel
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = (y * width + x) * 4

                let r = pixels[offset]
                let g = pixels[offset + 1]
                let b = pixels[offset + 2]

                // Quantize color to reduce similar colors (16 levels per channel)
                let quantR = (r / 16) * 16
                let quantG = (g / 16) * 16
                let quantB = (b / 16) * 16

                // Skip very dark (shadows) and very bright (highlights)
                let brightness = (Int(r) + Int(g) + Int(b)) / 3
                if brightness < 20 || brightness > 235 {
                    continue
                }

                let key = "\(quantR)-\(quantG)-\(quantB)"
                let color = UIColor(
                    red: CGFloat(quantR) / 255.0,
                    green: CGFloat(quantG) / 255.0,
                    blue: CGFloat(quantB) / 255.0,
                    alpha: 1.0
                )

                if var existing = colorCounts[key] {
                    existing.count += 1
                    colorCounts[key] = existing
                } else {
                    colorCounts[key] = (color: color, count: 1)
                }
            }
        }

        return Array(colorCounts.values)
    }

    /// Find dominant color from color histogram
    private static func findDominantColor(from colors: [(color: UIColor, count: Int)]) -> UIColor {
        // Group similar colors
        var colorGroups: [(color: UIColor, count: Int)] = []

        for entry in colors {
            var merged = false

            for i in 0..<colorGroups.count {
                if areColorsSimilar(entry.color, colorGroups[i].color, threshold: 0.15) {
                    // Merge with existing group
                    colorGroups[i].count += entry.count
                    merged = true
                    break
                }
            }

            if !merged {
                colorGroups.append(entry)
            }
        }

        // Find most common color
        guard let dominant = colorGroups.max(by: { $0.count < $1.count }) else {
            return UIColor(white: 0.15, alpha: 1.0)  // Fallback
        }

        // Darken the dominant color for better void fill (30% darker)
        return darkenColor(dominant.color, factor: 0.3)
    }

    /// Check if two colors are similar
    private static func areColorsSimilar(_ color1: UIColor, _ color2: UIColor, threshold: CGFloat) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let distance = sqrt(
            pow(r1 - r2, 2) +
            pow(g1 - g1, 2) +
            pow(b1 - b2, 2)
        )

        return distance < threshold
    }

    /// Darken a color by a factor (0-1)
    private static func darkenColor(_ color: UIColor, factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let darkFactor = 1.0 - factor
        return UIColor(
            red: r * darkFactor,
            green: g * darkFactor,
            blue: b * darkFactor,
            alpha: a
        )
    }

    /// Get color description for logging
    private static func colorDescription(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(format: "RGB(%.2f, %.2f, %.2f)", r, g, b)
    }
}
