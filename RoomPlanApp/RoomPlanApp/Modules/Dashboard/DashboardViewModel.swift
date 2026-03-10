//
//  DashboardViewModel.swift
//  RoomPlanApp
//
//  View model for the dashboard that displays all room scans
//

import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel: DashboardViewModelProtocol {
    var scans: [RoomScan] = []
    var isLoading = false
    var errorMessage: String?

    private let persistenceService: any PersistenceProtocol

    init(persistenceService: any PersistenceProtocol = PersistenceService.shared) {
        self.persistenceService = persistenceService
        debugPrint("📋 [DashboardVM] Initialized")
        // Don't load here - let the view trigger it with .task modifier
    }

    func loadScans() {
        debugPrint("📋 [DashboardVM] Loading scans...")
        isLoading = true
        errorMessage = nil

        do {
            scans = try persistenceService.loadAllScans()
            // Sort by most recently captured
            scans.sort { $0.captureDate > $1.captureDate }
            debugPrint("📋 [DashboardVM] ✅ Loaded \(scans.count) scans")
        } catch {
            debugPrint("📋 [DashboardVM] ❌ Failed to load scans: \(error.localizedDescription)")
            errorMessage = "Failed to load scans: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteScan(_ scan: RoomScan) {
        debugPrint("📋 [DashboardVM] Deleting scan: \(scan.name)")
        do {
            try persistenceService.deleteScan(scan)
            scans.removeAll { $0.id == scan.id }
            debugPrint("📋 [DashboardVM] ✅ Scan deleted successfully")
        } catch {
            debugPrint("📋 [DashboardVM] ❌ Failed to delete scan: \(error.localizedDescription)")
            errorMessage = "Failed to delete scan: \(error.localizedDescription)"
        }
    }

    func scanDisplayDate(_ scan: RoomScan) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: scan.captureDate, relativeTo: Date())
    }
}
