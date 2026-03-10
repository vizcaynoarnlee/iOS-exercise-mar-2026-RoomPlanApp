//
//  OrbitCamera.swift
//  RoomPlanApp
//
//  Camera with spherical orbit controls with smooth momentum
//

import SceneKit
import simd

/// Camera that orbits around a target position using spherical coordinates
class OrbitCamera {
    let cameraNode: SCNNode
    let targetNode: SCNNode  // Node at target position for constraint (must be in scene)

    // Spherical coordinates
    private(set) var distance: Float = 4.0      // Distance from target
    private(set) var azimuth: Float = 0.0       // Horizontal angle (radians)
    private(set) var elevation: Float = 0.3     // Vertical angle (radians)

    // Target to look at
    private(set) var targetPosition: SIMD3<Float> = .zero

    // Constraints
    let minDistance: Float = 0.5
    let maxDistance: Float = 20.0
    let minElevation: Float = -0.4  // ~-23° - can look slightly down but not too much
    let maxElevation: Float = 1.3   // ~75° - can look from above but not straight down

    // Momentum/inertia
    private var azimuthVelocity: Float = 0.0
    private var elevationVelocity: Float = 0.0
    private var isDecelerating = false
    private let decelerationRate: Float = 0.95  // Per frame (60fps)
    private var displayLink: CADisplayLink?

    init() {
        // Create camera node
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100

        // Create target node (invisible, just for constraint)
        targetNode = SCNNode()
        targetNode.position = SCNVector3(0, 0, 0)

        // Add look-at constraint with locked up vector
        let constraint = SCNLookAtConstraint(target: targetNode)
        constraint.isGimbalLockEnabled = true  // Prevents roll
        constraint.localFront = SCNVector3(0, 0, -1)
        constraint.worldUp = SCNVector3(0, 1, 0)  // Lock to world Y-axis
        cameraNode.constraints = [constraint]

        updateTransform()
    }

    deinit {
        stopInertia()
    }

    /// Frame camera to look at target at specified distance
    func frameTarget(at position: SIMD3<Float>, distance: Float) {
        self.targetPosition = position
        self.distance = clamp(distance, minDistance, maxDistance)

        // Reset angles for clean view
        self.azimuth = 0.0
        self.elevation = 0.3  // Slight downward angle

        // Update target node position
        targetNode.position = SCNVector3(position.x, position.y, position.z)

        updateTransform()

        debugPrint("🎥 [OrbitCamera] Framed target at \(position), distance: \(distance)")
    }

    /// Set orbit rotation to absolute values (from pan gesture)
    func setOrbit(azimuth: Float, elevation: Float) {
        stopInertia()  // Stop momentum when user touches again

        self.azimuth = azimuth
        self.elevation = clamp(elevation, minElevation, maxElevation)

        // Normalize azimuth to 0-2π
        self.azimuth = self.azimuth.truncatingRemainder(dividingBy: .pi * 2)

        updateTransform()
    }

    /// Start momentum with velocity (called when gesture ends)
    func applyMomentum(azimuthVelocity: Float, elevationVelocity: Float) {
        // Convert velocity to radians per frame (assuming 60fps)
        // Velocity comes in radians/second, convert to radians/frame
        self.azimuthVelocity = azimuthVelocity / 60.0
        self.elevationVelocity = elevationVelocity / 60.0

        // Only start momentum if velocity is significant
        let speed = sqrt(azimuthVelocity * azimuthVelocity + elevationVelocity * elevationVelocity)
        if speed > 0.01 {
            startInertia()
        }
    }

    /// Apply zoom (from pinch gesture)
    func applyZoom(delta: Float) {
        distance += delta
        distance = clamp(distance, minDistance, maxDistance)

        updateTransform()
    }

    /// Reset to default view
    func reset() {
        stopInertia()

        azimuth = 0.0
        elevation = 0.3
        distance = 4.0

        updateTransform()

        debugPrint("🎥 [OrbitCamera] Reset to default")
    }

    // MARK: - Inertia/Momentum

    private func startInertia() {
        guard !isDecelerating else { return }

        isDecelerating = true

        // Create display link for smooth 60fps updates
        displayLink = CADisplayLink(target: self, selector: #selector(updateInertia))
        displayLink?.add(to: .main, forMode: .common)

        debugPrint("🎥 [Inertia] Started with velocity: azimuth=\(azimuthVelocity), elevation=\(elevationVelocity)")
    }

    func stopInertia() {
        guard isDecelerating else { return }

        isDecelerating = false
        displayLink?.invalidate()
        displayLink = nil

        azimuthVelocity = 0.0
        elevationVelocity = 0.0
    }

    @objc private func updateInertia() {
        guard isDecelerating else { return }

        // Apply current velocity
        azimuth += azimuthVelocity
        elevation += elevationVelocity

        // Clamp elevation
        elevation = clamp(elevation, minElevation, maxElevation)

        // Apply exponential decay (like UIScrollView)
        azimuthVelocity *= decelerationRate
        elevationVelocity *= decelerationRate

        // Stop when velocity becomes negligible
        let speed = sqrt(azimuthVelocity * azimuthVelocity + elevationVelocity * elevationVelocity)
        if speed < 0.0001 {
            stopInertia()
            debugPrint("🎥 [Inertia] Stopped - velocity negligible")
        }

        updateTransform()
    }

    /// Update camera position based on spherical coordinates
    private func updateTransform() {
        // Convert spherical to Cartesian coordinates
        let x = distance * cos(elevation) * sin(azimuth)
        let y = distance * sin(elevation)
        let z = distance * cos(elevation) * cos(azimuth)

        let position = targetPosition + SIMD3<Float>(x, y, z)

        // Update camera position
        // The SCNLookAtConstraint automatically handles orientation
        // with gimbal lock enabled and world up locked to Y-axis
        cameraNode.position = SCNVector3(position.x, position.y, position.z)
    }

    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}
