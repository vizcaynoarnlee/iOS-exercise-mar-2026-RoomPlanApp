//
//  PersistenceProtocol.swift
//  RoomPlanApp
//
//  Protocol for persistence operations
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Protocol for persisting and loading scan data
protocol PersistenceProtocol: Sendable {
    /// Load all scans from storage
    func loadAllScans() throws -> [RoomScan]

    /// Delete a scan and all its files
    func deleteScan(_ scan: RoomScan) throws

    /// Save completed room scan with USDZ and photos
    func saveCompletedScan(
        name: String,
        usdzData: Data,
        photos: [(image: UIImage, pose: SpatialPose)]
    ) throws -> RoomScan
}

// MARK: - Make PersistenceService conform to protocol
extension PersistenceService: PersistenceProtocol {}
