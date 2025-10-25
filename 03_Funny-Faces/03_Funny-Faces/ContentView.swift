//
//  ContentView.swift
//  03_Funny-Faces
//
//  Created by Ashok Vardhan Jangeti on 20/10/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FunnyFaceViewModel()
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                imageSection
                    .frame(minHeight: 280)
                    .padding(.horizontal)

                controlsSection
                    .padding(.horizontal)

                actionSection
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button(action: { viewModel.reset() }) {
                        Label("Reset", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.processedImage == nil && viewModel.inputImage == nil)

                    if let processed = viewModel.processedImage {
                        // UIImage does not conform to Transferable. Convert to Data (JPEG) for sharing.
                        if let imageData = processed.jpegData(compressionQuality: 0.9) {
                            ShareLink(item: imageData, preview: SharePreview("My Funny Face", image: Image(uiImage: processed))) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            // Fallback: show a disabled label if we can't encode the image
                            Label("Share Unavailable", systemImage: "square.and.arrow.up")
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    if viewModel.isProcessing {
                        ProgressView("Processing...")
                    }
                }
                .padding(.horizontal)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Funny Faces")
        }
        // Present a modal alert when the view model has an error message.
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { newValue in if !newValue { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Subviews to simplify type-checking
    @ViewBuilder private var imageSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Group {
                if let img = viewModel.displayImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            // quick tap applies the currently selected effects (same as Apply Filter)
                            if viewModel.canApplyFilter {
                                Task { await viewModel.applyFilter() }
                            } else {
                                if viewModel.inputImage == nil {
                                    viewModel.errorMessage = "Please import an image first."
                                } else if viewModel.processedImage != nil {
                                    viewModel.errorMessage = "A filter has already been applied. Reset or import a new image to apply again."
                                } else if !(viewModel.eyeOverlay != .none || viewModel.goofyChecked) {
                                    viewModel.errorMessage = "No effect selected. Choose an overlay or enable Goofy Smile, then tap Apply Filter (or tap the image) to apply."
                                } else {
                                    viewModel.errorMessage = "Processing is already running. Please wait."
                                }
                            }
                        }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Import a photo to get started")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder private var controlsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Feature:")
                    .font(.subheadline)
                Picker("Feature", selection: $viewModel.selectedFeature) {
                    ForEach(FacialFeature.allCases) { feat in
                        Text(feat.rawValue).tag(feat)
                    }
                }
                .pickerStyle(.menu)
                // Disable the feature picker until an image is loaded, and also when options are locked
                .disabled(!viewModel.hasImage || viewModel.optionsLocked)
            }

            HStack(spacing: 12) {
                Picker("Eye Overlay", selection: $viewModel.eyeOverlay) {
                    ForEach(EyeOverlay.allCases, id: \.self) { o in
                        Text(o.rawValue).tag(o)
                    }
                }
                .pickerStyle(.segmented)
                // Disable until an image is loaded or options are locked; still respect the per-feature enabled state
                .disabled(!viewModel.hasImage || viewModel.optionsLocked || !viewModel.eyeOverlayEnabled)

                // Goofy smile presented as a checkbox-style button
                Button(action: {
                    if viewModel.goofyToggleEnabled {
                        viewModel.goofyChecked.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.goofyChecked ? "checkmark.square" : "square")
                        Text("Goofy Smile")
                    }
                }
                // Disable until an image is loaded or options are locked; still respect the per-feature enabled state
                .disabled(!viewModel.hasImage || viewModel.optionsLocked || !viewModel.goofyToggleEnabled)
            }
        }
    }

    @ViewBuilder private var actionSection: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Import Photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .onChange(of: photoItem) { _, newValue in
                Task {
                    await viewModel.loadPhoto(item: newValue)
                    // clear the binding so the same photo can be selected again
                    photoItem = nil
                }
            }

            Button(action: {
                Task { await viewModel.applyFilter() }
            }) {
                Label("Apply Filter", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            // Disable Apply when the view-model says the filter can't be applied, and also when options are locked
            .disabled(!viewModel.canApplyFilter || viewModel.optionsLocked)
        }
    }
}

#Preview {
    ContentView()
}
