//
//  RoomViewerViewModel.swift
//  RoomPlanApp
//
//  View model for viewing a completed room scan
//

import Foundation
import Observation

@MainActor
@Observable
final class RoomViewerViewModel: RoomViewerViewModelProtocol {
    var scan: RoomScan
    var isLoading = false
    var errorMessage: String?

    init(scan: RoomScan) {
        self.scan = scan
        debugPrint("🎨 [RoomViewerVM] Initialized for scan: \(scan.name)")
        debugPrint("🎨 [RoomViewerVM] Photos: \(scan.photos.count)")
    }
}
