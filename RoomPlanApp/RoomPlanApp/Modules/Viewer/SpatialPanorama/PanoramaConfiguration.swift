//
//  PanoramaConfiguration.swift
//  RoomPlanApp
//
//  Configuration values for 360° panorama viewer
//

import Foundation
import CoreGraphics
import simd

/// Configuration constants for panorama rendering
enum PanoramaConfiguration {

    // MARK: - Sphere Geometry

    /// Radius of the panorama sphere in meters
    static let sphereRadius: CGFloat = 10.0

    // MARK: - Camera Intrinsics

    /// Default captured image width in pixels
    static let defaultImageWidth: CGFloat = 1920

    /// Default captured image height in pixels
    static let defaultImageHeight: CGFloat = 1440

    /// Default camera field of view for capture in degrees
    static let captureFieldOfView: Float = 90.0

    /// Camera forward direction vector in local space
    static let cameraForwardDirection = SIMD3<Float>(0, 0, -1)

    /// Identity quaternion for rotation calculations
    static let identityQuaternion = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    // MARK: - Camera Settings

    /// Default camera field of view in degrees
    static let defaultFOV: CGFloat = 75.0

    /// Maximum field of view (most zoomed out) in degrees
    static let maxFOV: CGFloat = 120.0

    /// Minimum field of view (most zoomed in) in degrees
    static let minFOV: CGFloat = 30.0

    // MARK: - Gesture Controls

    /// Sensitivity multiplier for pan gesture (higher = more responsive)
    static let panSensitivity: Float = 0.005

    /// Margin from vertical extremes to prevent gimbal lock (in radians)
    static let pitchClampMargin: Float = 0.1

    // MARK: - Equirectangular Image

    /// Canvas width for equirectangular image (2:1 aspect ratio)
    static let canvasWidth: CGFloat = 4096

    /// Canvas height for equirectangular image (2:1 aspect ratio)
    static let canvasHeight: CGFloat = 2048

    // MARK: - Photo Projection

    /// Angular width of each photo on canvas in radians (~57°)
    static let photoAngularWidth: Float = 1.0

    /// Angular height of each photo on canvas in radians (~57°)
    static let photoAngularHeight: Float = 1.0

    // MARK: - Blending

    /// Edge feather amount in pixels for seam softening
    /// Increased from 4 to 20 for better blending
    static let seamFeatherPixels: CGFloat = 20.0

    /// Use subtle edge softening for smoother seams
    static let useSeamSoftening: Bool = true

    // MARK: - Feature Alignment

    /// Enable feature-based alignment correction
    static let useFeatureAlignment: Bool = true

    /// Search radius for feature matching in pixels
    static let alignmentSearchRadius: CGFloat = 50.0

    /// Maximum alignment correction as fraction of photo size (5%)
    static let maxAlignmentCorrection: CGFloat = 0.05

    /// Minimum number of feature matches required for alignment
    static let minFeatureMatches: Int = 10

    // MARK: - Camera Pose Refinement

    /// Enable bundle adjustment for refining camera orientations
    static let usePoseRefinement: Bool = true

    /// Minimum matched features required for pose refinement
    static let minFeaturesForRefinement: Int = 6

    /// Maximum rotation adjustment in radians (prevent large jumps)
    static let maxRotationAdjustment: Float = 0.1  // ~5.7 degrees

    /// Optimization iterations for bundle adjustment
    static let bundleAdjustmentIterations: Int = 50

    /// Minimum angular error threshold for applying adjustment (radians)
    static let minErrorForAdjustment: Float = 0.001

    /// Interpolation factor for accumulating quaternion adjustments (0-1)
    static let adjustmentInterpolationFactor: Float = 0.5

    /// Convergence threshold in degrees for early stopping
    static let convergenceThreshold: Float = 0.5

    /// Iteration logging frequency (log every N iterations)
    static let loggingFrequency: Int = 10

    /// Minimum axis length for valid rotation calculation
    static let minAxisLength: Float = 0.001

    // MARK: - Multi-Band Blending

    /// Enable GPU-accelerated multi-band pyramid blending
    static let useMultiBandBlending: Bool = true

    /// Number of pyramid levels for multi-band blending
    static let pyramidLevels: Int = 3

    /// Feather distance for blend masks in pixels
    static let blendFeatherPixels: CGFloat = 20.0

    // MARK: - Gain Compensation

    /// Enable exposure and color gain compensation
    static let useGainCompensation: Bool = true

    /// Minimum overlap percentage to use for gain calculation (15%)
    static let minOverlapForGain: Float = 0.15

    /// Minimum gain multiplier (prevents over-darkening)
    static let minGainMultiplier: Float = 0.5

    /// Maximum gain multiplier (prevents over-brightening)
    static let maxGainMultiplier: Float = 2.0

    /// Luminance weight for red channel (ITU-R BT.601 standard)
    static let luminanceWeightRed: Float = 0.299

    /// Luminance weight for green channel (ITU-R BT.601 standard)
    static let luminanceWeightGreen: Float = 0.587

    /// Luminance weight for blue channel (ITU-R BT.601 standard)
    static let luminanceWeightBlue: Float = 0.114

    // MARK: - Overlap Detection

    /// Minimum overlap percentage to consider for blending (10%)
    static let overlapDetectionThreshold: Float = 0.10
}
