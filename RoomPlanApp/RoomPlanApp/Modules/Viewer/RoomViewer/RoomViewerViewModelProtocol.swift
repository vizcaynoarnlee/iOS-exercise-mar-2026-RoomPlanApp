//
//  RoomViewerViewModelProtocol.swift
//  RoomPlanApp
//
//  Protocol defining the public interface for RoomViewer ViewModel
//

import Foundation

/// Protocol for RoomViewer ViewModel
/// Manages display of a completed room scan
@MainActor
protocol RoomViewerViewModelProtocol: AnyObject, Observable {
    /// The room scan being viewed
    var scan: RoomScan { get }

    /// Loading state indicator
    var isLoading: Bool { get }

    /// Error message to display to user
    var errorMessage: String? { get set }
}
