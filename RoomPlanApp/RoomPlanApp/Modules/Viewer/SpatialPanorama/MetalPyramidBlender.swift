//
//  MetalPyramidBlender.swift
//  RoomPlanApp
//
//  GPU-accelerated multi-band pyramid blending using Metal
//

import Foundation
import Metal
import UIKit
import CoreImage

/// Metal-based pyramid blending for seamless image stitching
class MetalPyramidBlender {

    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineStates: [String: MTLComputePipelineState] = [:]

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        // Load shader library and create pipeline states
        do {
            try loadShaders()
        } catch {
            debugPrint("❌ [Metal] Failed to load shaders: \(error)")
            return nil
        }
    }

    /// Load Metal shaders and create compute pipeline states
    private func loadShaders() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw NSError(domain: "MetalPyramidBlender", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create default library"])
        }

        let kernelNames = [
            "gaussianDownsample",
            "upsample",
            "computeLaplacian",
            "pyramidBlend",
            "addPyramidLevels",
            "createDistanceFieldMask"
        ]

        for name in kernelNames {
            guard let function = library.makeFunction(name: name) else {
                throw NSError(domain: "MetalPyramidBlender", code: 2,
                             userInfo: [NSLocalizedDescriptionKey: "Function \(name) not found"])
            }

            let pipelineState = try device.makeComputePipelineState(function: function)
            pipelineStates[name] = pipelineState
        }

        debugPrint("✅ [Metal] Loaded \(kernelNames.count) shader kernels")
    }

    // MARK: - Public Interface

    /// Blend two images using multi-band pyramid blending
    /// - Parameters:
    ///   - image1: First image
    ///   - image2: Second image
    ///   - mask: Blend mask (grayscale: 0 = image1, 1 = image2)
    ///   - levels: Number of pyramid levels (default: 3)
    /// - Returns: Blended image
    func blendImages(
        _ image1: UIImage,
        _ image2: UIImage,
        mask: UIImage,
        levels: Int = 3
    ) -> UIImage? {
        guard let texture1 = createTexture(from: image1),
              let texture2 = createTexture(from: image2),
              let maskTexture = createTexture(from: mask) else {
            return nil
        }

        // Create Gaussian pyramids
        guard let pyramid1 = createGaussianPyramid(texture1, levels: levels),
              let pyramid2 = createGaussianPyramid(texture2, levels: levels),
              let maskPyramid = createGaussianPyramid(maskTexture, levels: levels) else {
            return nil
        }

        // Create Laplacian pyramids
        guard let laplacian1 = createLaplacianPyramid(pyramid1),
              let laplacian2 = createLaplacianPyramid(pyramid2) else {
            return nil
        }

        // Blend each pyramid level
        var blendedPyramid: [MTLTexture] = []
        for level in 0..<levels {
            guard let blended = blendLevel(
                laplacian1[level],
                laplacian2[level],
                maskPyramid[level]
            ) else {
                return nil
            }
            blendedPyramid.append(blended)
        }

        // Reconstruct final image from blended pyramid
        return reconstructPyramid(blendedPyramid)
    }

    // MARK: - Pyramid Construction

    /// Create Gaussian pyramid by iterative downsampling
    private func createGaussianPyramid(_ texture: MTLTexture, levels: Int) -> [MTLTexture]? {
        var pyramid: [MTLTexture] = [texture]

        for level in 1..<levels {
            let prevTexture = pyramid[level - 1]

            // Create texture at half resolution
            guard let downsampled = createHalfSizeTexture(from: prevTexture) else {
                return nil
            }

            // Apply Gaussian blur and downsample
            guard downsample(prevTexture, to: downsampled) else {
                return nil
            }

            pyramid.append(downsampled)
        }

        return pyramid
    }

    /// Create Laplacian pyramid: original - upsampled(next_level)
    private func createLaplacianPyramid(_ gaussianPyramid: [MTLTexture]) -> [MTLTexture]? {
        var laplacianPyramid: [MTLTexture] = []

        for level in 0..<(gaussianPyramid.count - 1) {
            let original = gaussianPyramid[level]
            let blurred = gaussianPyramid[level + 1]

            // Upsample blurred to match original size
            guard let upsampled = createTexture(width: original.width, height: original.height),
                  upsampleTexture(blurred, to: upsampled) else {
                return nil
            }

            // Compute Laplacian: original - upsampled
            guard let laplacian = createTexture(width: original.width, height: original.height),
                  computeLaplacianTexture(original, upsampled, to: laplacian) else {
                return nil
            }

            laplacianPyramid.append(laplacian)
        }

        // Last level is just the lowest resolution Gaussian
        laplacianPyramid.append(gaussianPyramid.last!)

        return laplacianPyramid
    }

    // MARK: - Metal Operations

    /// Gaussian downsample using Metal kernel
    private func downsample(_ input: MTLTexture, to output: MTLTexture) -> Bool {
        guard let pipelineState = pipelineStates["gaussianDownsample"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (output.width + 7) / 8,
            height: (output.height + 7) / 8,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return true
    }

    /// Upsample texture using bilinear interpolation
    private func upsampleTexture(_ input: MTLTexture, to output: MTLTexture) -> Bool {
        guard let pipelineState = pipelineStates["upsample"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (output.width + 7) / 8,
            height: (output.height + 7) / 8,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return true
    }

    /// Compute Laplacian: original - upsampled
    private func computeLaplacianTexture(
        _ original: MTLTexture,
        _ upsampled: MTLTexture,
        to output: MTLTexture
    ) -> Bool {
        guard let pipelineState = pipelineStates["computeLaplacian"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(original, index: 0)
        encoder.setTexture(upsampled, index: 1)
        encoder.setTexture(output, index: 2)

        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (output.width + 7) / 8,
            height: (output.height + 7) / 8,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return true
    }

    /// Blend two pyramid levels using mask
    private func blendLevel(
        _ pyramid1: MTLTexture,
        _ pyramid2: MTLTexture,
        _ mask: MTLTexture
    ) -> MTLTexture? {
        guard let output = createTexture(width: pyramid1.width, height: pyramid1.height),
              let pipelineState = pipelineStates["pyramidBlend"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(pyramid1, index: 0)
        encoder.setTexture(pyramid2, index: 1)
        encoder.setTexture(mask, index: 2)
        encoder.setTexture(output, index: 3)

        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (output.width + 7) / 8,
            height: (output.height + 7) / 8,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return output
    }

    // MARK: - Pyramid Reconstruction

    /// Reconstruct image from Laplacian pyramid
    private func reconstructPyramid(_ laplacianPyramid: [MTLTexture]) -> UIImage? {
        // Start with lowest resolution level
        var current = laplacianPyramid.last!

        // Work upwards, adding detail at each level
        for level in stride(from: laplacianPyramid.count - 2, through: 0, by: -1) {
            let laplacian = laplacianPyramid[level]

            // Upsample current to match laplacian size
            guard let upsampled = createTexture(width: laplacian.width, height: laplacian.height),
                  upsampleTexture(current, to: upsampled) else {
                return nil
            }

            // Add laplacian detail
            guard let result = createTexture(width: laplacian.width, height: laplacian.height),
                  addTextures(laplacian, upsampled, to: result) else {
                return nil
            }

            current = result
        }

        // Convert final texture to UIImage
        return createImage(from: current)
    }

    /// Add two textures together
    private func addTextures(
        _ texture1: MTLTexture,
        _ texture2: MTLTexture,
        to output: MTLTexture
    ) -> Bool {
        guard let pipelineState = pipelineStates["addPyramidLevels"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture1, index: 0)
        encoder.setTexture(texture2, index: 1)
        encoder.setTexture(output, index: 2)

        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (output.width + 7) / 8,
            height: (output.height + 7) / 8,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return true
    }

    // MARK: - Texture Utilities

    /// Create Metal texture from UIImage
    private func createTexture(from image: UIImage) -> MTLTexture? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        // Copy image data to texture
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return nil
        }

        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )

        return texture
    }

    /// Create empty Metal texture
    private func createTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        return device.makeTexture(descriptor: descriptor)
    }

    /// Create texture at half size
    private func createHalfSizeTexture(from texture: MTLTexture) -> MTLTexture? {
        return createTexture(width: texture.width / 2, height: texture.height / 2)
    }

    /// Convert Metal texture to UIImage
    private func createImage(from texture: MTLTexture) -> UIImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4

        var data = [UInt8](repeating: 0, count: width * height * 4)

        texture.getBytes(
            &data,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
              let cgImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
