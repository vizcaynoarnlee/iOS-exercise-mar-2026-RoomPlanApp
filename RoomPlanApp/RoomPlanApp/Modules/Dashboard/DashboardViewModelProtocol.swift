//
//  DashboardViewModelProtocol.swift
//  RoomPlanApp
//
//  Protocol defining the public interface for Dashboard ViewModel
//

import Foundation

/// Protocol for Dashboard ViewModel
/// Manages the list of saved room scans
@MainActor
protocol DashboardViewModelProtocol: AnyObject, Observable {
    /// All saved room scans, sorted by date
    var scans: [RoomScan] { get }

    /// Loading state indicator
    var isLoading: Bool { get }

    /// Error message to display to user
    var errorMessage: String? { get set }

    /// Load all scans from storage
    func loadScans()

    /// Delete a specific scan
    func deleteScan(_ scan: RoomScan)

    /// Format scan date for display
    func scanDisplayDate(_ scan: RoomScan) -> String
}
