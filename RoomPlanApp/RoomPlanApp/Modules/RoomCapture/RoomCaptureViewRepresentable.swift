//
//  RoomCaptureViewRepresentable.swift
//  RoomPlanApp
//
//  UIKit integration for RoomPlan's capture view
//

import SwiftUI
import RoomPlan

/// UIViewControllerRepresentable wrapper for RoomPlan's RoomCaptureView
struct RoomCaptureViewRepresentable: UIViewControllerRepresentable {
    let viewModel: RoomCaptureViewModel

    func makeUIViewController(context: Context) -> RoomCaptureViewController {
        let controller = RoomCaptureViewController(viewModel: viewModel)
        return controller
    }

    func updateUIViewController(_ uiViewController: RoomCaptureViewController, context: Context) {
        // No updates needed
    }
}

/// UIViewController that hosts RoomPlan's capture view
final class RoomCaptureViewController: UIViewController {
    private let viewModel: RoomCaptureViewModel
    private var roomCaptureView: RoomPlan.RoomCaptureView?
    private var coordinator: RoomCaptureCoordinator?

    init(viewModel: RoomCaptureViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create and configure RoomCaptureView
        // RoomCaptureView creates and owns its own RoomCaptureSession
        let captureView = RoomPlan.RoomCaptureView(frame: view.bounds)

        view.addSubview(captureView)
        captureView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureView.topAnchor.constraint(equalTo: view.topAnchor),
            captureView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            captureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            captureView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        self.roomCaptureView = captureView

        // Create coordinator and set as session delegate
        let coord = viewModel.createCoordinator(captureSession: captureView.captureSession)
        coordinator = coord

        // Set coordinator as session delegate (for scan data updates)
        captureView.captureSession.delegate = coord

        debugPrint("🎯 [RoomCaptureVC] Connected coordinator as session delegate")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Check permissions before starting
        Task { @MainActor in
            let hasPermission = await viewModel.checkPermissions()
            if hasPermission {
                viewModel.startCapture()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopCapture()
    }
}
