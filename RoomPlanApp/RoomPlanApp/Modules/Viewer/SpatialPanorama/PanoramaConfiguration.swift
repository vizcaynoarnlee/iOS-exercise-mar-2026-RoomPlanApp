//
//  PanoramaConfiguration.swift
//  RoomPlanApp
//
//  Configuration values for 360° panorama viewer
//

import Foundation
import CoreGraphics

/// Configuration constants for panorama rendering
enum PanoramaConfiguration {

    // MARK: - Sphere Geometry

    /// Radius of the panorama sphere in meters
    static let sphereRadius: CGFloat = 10.0

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
    /// Small value (2-5 pixels) softens seams without ghosting
    static let seamFeatherPixels: CGFloat = 4.0

    /// Use subtle edge softening for smoother seams
    static let useSeamSoftening: Bool = true
}
