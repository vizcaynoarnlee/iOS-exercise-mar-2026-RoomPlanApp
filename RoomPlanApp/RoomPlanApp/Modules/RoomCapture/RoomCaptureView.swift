//
//  RoomCaptureView.swift
//  RoomPlanApp
//
//  View for capturing room scans with RoomPlan
//

import SwiftUI
import RoomPlan

struct RoomCaptureView: View {
    @State private var viewModel: RoomCaptureViewModel
    @State private var showingNameDialog = false
    @State private var roomName = ""
    @Environment(\.dismiss) private var dismiss

    init(onComplete: @escaping (RoomScan) -> Void) {
        _viewModel = State(initialValue: RoomCaptureViewModel(onComplete: onComplete))
    }

    var body: some View {
        ZStack {
            // RoomPlan's capture view
            RoomCaptureViewRepresentable(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                // Saving indicator
                if viewModel.isSaving {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Saving room scan...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(25)
                    .padding(.top, 20)
                }

                Spacer()

                // Bottom controls
                HStack(alignment: .bottom) {
                    // Finish button (lower left)
                    if viewModel.canExport {
                        Button(action: {
                            roomName = viewModel.generateDefaultRoomName()
                            showingNameDialog = true
                        }) {
                            Text("Finish")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(25)
                        }
                        .disabled(viewModel.isSaving)
                        .opacity(viewModel.isSaving ? 0.2 : 1.0)
                    }

                    Spacer()

                    // Right side stack: Photo counter + Take Photo button
                    VStack(alignment: .trailing, spacing: 12) {
                        // Photo count indicator (above Take Photo button)
                        if !viewModel.capturedPhotos.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 14))
                                Text("\(viewModel.capturedPhotos.count)")
                                    .font(.body)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(25)
                        }

                        // Take Photo button (lower right)
                        if viewModel.isCapturing && !viewModel.isSaving {
                            Button(action: {
                                Task {
                                    await viewModel.capturePhoto()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                    Text("Take Photo")
                                        .font(.body)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(25)
                            }
                            .disabled(viewModel.isProcessingPhoto)
                        }
                    }
                    .opacity(viewModel.isProcessingPhoto ? 0.2 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Scan Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.stopCapture()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .disabled(viewModel.isSaving)
            }
        }
        .alert("Name Your Room", isPresented: $showingNameDialog) {
            TextField("Room name", text: $roomName)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                showingNameDialog = false
            }
            Button("Save") {
                let finalName = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalName.isEmpty {
                    viewModel.finishCapture(withName: finalName)
                }
            }
        } message: {
            Text("Enter a name for this room scan")
        }
    }
}

// MARK: - Previews

#Preview("Initial State") {
    NavigationStack {
        RoomCapturePreviewWrapper(
            isCapturing: true,
            canExport: false,
            photoCount: 0,
            isSaving: false,
            errorMessage: nil
        )
    }
}

#Preview("With Photos") {
    NavigationStack {
        RoomCapturePreviewWrapper(
            isCapturing: true,
            canExport: true,
            photoCount: 5,
            isSaving: false,
            errorMessage: nil
        )
    }
}

#Preview("Saving") {
    NavigationStack {
        RoomCapturePreviewWrapper(
            isCapturing: false,
            canExport: true,
            photoCount: 8,
            isSaving: true,
            errorMessage: nil
        )
    }
}

#Preview("Error State") {
    NavigationStack {
        RoomCapturePreviewWrapper(
            isCapturing: true,
            canExport: false,
            photoCount: 2,
            isSaving: false,
            errorMessage: "Failed to capture photo"
        )
    }
}

#Preview("With Photos - Dark Mode") {
    NavigationStack {
        RoomCapturePreviewWrapper(
            isCapturing: true,
            canExport: true,
            photoCount: 5,
            isSaving: false,
            errorMessage: nil
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("With Photos - Light Mode") {
    NavigationStack {
        RoomCapturePreviewWrapper(
            isCapturing: true,
            canExport: true,
            photoCount: 5,
            isSaving: false,
            errorMessage: nil
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Name Dialog") {
    @Previewable @State var showDialog = true
    @Previewable @State var name = "Living Room"

    NavigationStack {
        RoomCapturePreviewWrapper(
            isCapturing: true,
            canExport: true,
            photoCount: 8,
            isSaving: false,
            errorMessage: nil
        )
    }
    .alert("Name Your Room", isPresented: $showDialog) {
        TextField("Room name", text: $name)
            .autocorrectionDisabled()
        Button("Cancel", role: .cancel) {}
        Button("Save") {}
    } message: {
        Text("Enter a name for this room scan")
    }
}

/// Preview wrapper that shows the UI overlay without requiring AR hardware
private struct RoomCapturePreviewWrapper: View {
    let isCapturing: Bool
    let canExport: Bool
    let photoCount: Int
    let isSaving: Bool
    let errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @State private var isProcessingPhoto = false
    @State private var showingNameDialog = false
    @State private var roomName = "Room Scan 1"

    var body: some View {
        ZStack {
            // Mock camera background - adapts to dark/light mode
            Color(.systemGray5)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI (same as RoomCaptureView)
            VStack {
                // Saving indicator
                if isSaving {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Saving room scan...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(25)
                    .padding(.top, 20)
                }

                Spacer()

                // Bottom controls
                HStack(alignment: .bottom) {
                    // Finish button (lower left)
                    if canExport {
                        Button(action: {
                            showingNameDialog = true
                        }) {
                            Text("Finish")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(25)
                        }
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.2 : 1.0)
                    }

                    Spacer()

                    // Right side stack: Photo counter + Take Photo button
                    VStack(alignment: .trailing, spacing: 12) {
                        // Photo count indicator (above Take Photo button)
                        if photoCount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 14))
                                Text("\(photoCount)")
                                    .font(.body)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(25)
                        }

                        // Take Photo button (lower right)
                        if isCapturing && !isSaving {
                            Button(action: {
                                isProcessingPhoto = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isProcessingPhoto = false
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                    Text("Take Photo")
                                        .font(.body)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(25)
                            }
                            .disabled(isProcessingPhoto)
                        }
                    }
                    .opacity(isProcessingPhoto ? 0.2 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Room Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .disabled(isSaving)
            }
        }
        .alert("Name Your Room", isPresented: $showingNameDialog) {
            TextField("Room name", text: $roomName)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                showingNameDialog = false
            }
            Button("Save") {
                // Preview only - doesn't actually save
                showingNameDialog = false
            }
        } message: {
            Text("Enter a name for this room scan")
        }
    }
}
