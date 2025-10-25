//
//  FunnyFaceViewModel.swift
//  03_Funny-Faces
//
//  Created by Ashok Vardhan Jangeti on 20/10/25.
//

import Foundation
import SwiftUI
import PhotosUI
import Combine
import Foundation
import SwiftUI
import PhotosUI
import Combine

@MainActor
final class FunnyFaceViewModel: ObservableObject {
    @Published var inputImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var originalImage: UIImage? // store the original loaded image explicitly
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    
    // New: user's choice of which facial feature to modify and which overlay to apply
    @Published var selectedFeature: FacialFeature = .all {
        didSet {
            // Auto-select overlay switches/checkmark based on selected feature
            switch selectedFeature {
            case .leftEye, .rightEye:
                // Default: suggest sunglasses for a single eye selection; disable goofy
                eyeOverlay = .sunglasses
                goofyChecked = false
            case .mouth:
                // Default: mouth targets goofy smile; disable eye overlay picker
                eyeOverlay = nil
                goofyChecked = true
            case .all:
                // For 'all' allow the user to choose an eye overlay (default none) and enable goofy
                eyeOverlay = .googly
                goofyChecked = false
            }
        }
    }
    
    // UI state: single picker for eye overlay (googly / sunglasses) and checklist for goofy smile
    @Published var eyeOverlay: EyeOverlay? = .googly
    @Published var goofyChecked: Bool = false
    
    // Per-toggle enabled state — control which toggles are interactive based on feature
    // Eye overlay picker enabled when feature is not strictly mouth
    var eyeOverlayEnabled: Bool { selectedFeature != .mouth }
    // Goofy checkbox enabled for mouth or all
    var goofyToggleEnabled: Bool { selectedFeature == .all || selectedFeature == .mouth }
    
    // Derived UI enable/disable states (legacy)
    var switchesEnabled: Bool { selectedFeature != .mouth }
    var goofyEnabled: Bool { goofyToggleEnabled }

    // Computed convenience booleans for enabling/disabling action buttons
    var canApplyGoogly: Bool { (originalImage ?? inputImage) != nil && processedImage == nil && !isProcessing && (selectedFeature == .all || selectedFeature == .leftEye || selectedFeature == .rightEye) }
    // can apply filter if at least one effect is selected (eye overlay != none or goofy checked)
    var canApplyFilter: Bool {
        let hasEffects = (eyeOverlay != .none) || goofyChecked
        return (originalImage ?? inputImage) != nil && processedImage == nil && !isProcessing && hasEffects
    }

    // New convenience: whether we currently have an image available (original or loaded)
    var hasImage: Bool { (originalImage ?? inputImage) != nil }

    // Controls should be locked when processing is in flight or a processed image exists
    // This is used by the UI to disable options after Apply is clicked (and while processing/completed).
    var optionsLocked: Bool { isProcessing || processedImage != nil }

    // Token to track the most recent processing request. Only results matching this token will be applied.
    private var currentProcessingToken: UUID?
    
    var displayImage: UIImage? {
        // Prefer processed image, fall back to input; normalize orientation and scale for display
        if let proc = processedImage {
            return normalizedForDisplay(proc)
        }
        if let inp = inputImage {
            return normalizedForDisplay(inp)
        }
        return nil
    }
    
    // Return a CGImage-backed UIImage with .up orientation and appropriate scale for display
    private func normalizedForDisplay(_ img: UIImage) -> UIImage {
        if let cg = img.cgImage {
            let targetScale = originalImage?.scale ?? img.scale
            return UIImage(cgImage: cg, scale: targetScale, orientation: .up)
        }
        if let rendered = img.renderedCGImage() {
            let targetScale = originalImage?.scale ?? img.scale
            return UIImage(cgImage: rendered, scale: targetScale, orientation: .up)
        }
        return img
    }
    
    // Whether it's valid to apply the googly-eyes filter now.
    // True only when we have an original image and no processed image yet and not already processing.
    var canApply: Bool { (originalImage ?? inputImage) != nil && processedImage == nil && !isProcessing }
    
    // MARK: - Photo Loading
    func loadPhoto(item: PhotosPickerItem?) async {
        errorMessage = nil
        guard let item = item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                // Normalize the loaded image to a CGImage-backed UIImage with scale = 1 so processing
                // always starts from the same canonical pixel buffer. This avoids subtle scale/orientation
                // differences that can cause overlays to compound.
                // Always render the UIImage into a new CGImage to bake orientation into the pixels.
                if let baked = uiImage.renderedCGImage() {
                    let normalized = UIImage(cgImage: baked, scale: 1.0, orientation: .up)
                    self.inputImage = normalized
                    self.originalImage = normalized
                } else if let cg = uiImage.cgImage {
                    // Fallback: if rendering failed, use the cgImage but force .up orientation
                    let normalized = UIImage(cgImage: cg, scale: 1.0, orientation: .up)
                    self.inputImage = normalized
                    self.originalImage = normalized
                } else {
                    // Last-resort: keep the original UIImage
                    self.inputImage = uiImage
                    self.originalImage = uiImage
                }
                // Clear any previous processed image and processing token/state so this is treated as a fresh image
                self.processedImage = nil
                self.currentProcessingToken = nil
                self.isProcessing = false
                self.errorMessage = nil
            } else {
                self.errorMessage = "Failed to load image data."
            }
        } catch {
            self.errorMessage = "Error loading image: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Processing
    /// Synchronously prepare for processing. Returns a token if processing can start, otherwise nil.
    func startProcessingIfAvailable() -> UUID? {
        // If already processing, refuse
        if isProcessing { return nil }
        // Use the original image as the source
        guard originalImage != nil || inputImage != nil else { return nil }
        
        // Do not start if we've already applied to this image
        if processedImage != nil { return nil }
        
        // Clear prior processed image and set the UI to show the original
        processedImage = nil
        inputImage = originalImage
        
        // Mark processing and create token
        isProcessing = true
        let token = UUID()
        currentProcessingToken = token
        return token
    }
    
    func applyGooglyEyes() async {
        // keep present for API compatibility (not used by UI)
        errorMessage = nil
        
        // Ensure selectedFeature includes one of the eyes
        guard selectedFeature == .all || selectedFeature == .leftEye || selectedFeature == .rightEye else {
            errorMessage = "Googly eyes only apply to eyes. Select Left, Right or All."
            return
        }
        
        // If processing hasn't been started synchronously, try to start now
        let token: UUID
        if let current = currentProcessingToken {
            token = current
        } else if let t = startProcessingIfAvailable() {
            token = t
        } else {
            print("[FunnyFaceViewModel] applyGooglyEyes: unable to start processing (already running or no image)")
            return
        }
        
        // Use the current original/input image as source
        guard let input = originalImage ?? inputImage else {
            errorMessage = "Please import an image first."
            isProcessing = false
            currentProcessingToken = nil
            return
        }
        
        print("[FunnyFaceViewModel] Starting googly-eye processing. token=\(token)")
        
        defer {
            // clear token only if it still matches
            if currentProcessingToken == token {
                currentProcessingToken = nil
            }
            isProcessing = false
        }
        
        do {
            // Construct a fresh UIImage source from the original's CGImage (if available) to avoid
            // accidental processing of an already-processed UIImage instance.
            let source: UIImage
            if let cg = input.cgImage {
                source = UIImage(cgImage: cg, scale: input.scale, orientation: .up)
            } else if let rendered = input.renderedCGImage() {
                source = UIImage(cgImage: rendered, scale: input.scale, orientation: .up)
            } else {
                source = input
            }
            
            // Only apply googly eyes, not overlays
            let output = try await FaceProcessor.shared.process(image: source, selectedFeature: selectedFeature, applyGoogly: true, applySunglasses: false, applyGoofy: false)
            
            guard self.currentProcessingToken == token else {
                print("[FunnyFaceViewModel] Discarding stale processing result for token=\(token)")
                return
            }
            
            // Normalize output to a CGImage-backed UIImage with .up orientation and original scale
            if let outCG = output.cgImage {
                let finalScale = self.originalImage?.scale ?? output.scale
                let normalizedOut = UIImage(cgImage: outCG, scale: finalScale, orientation: .up)
                self.processedImage = normalizedOut
            } else if let rendered = output.renderedCGImage() {
                let finalScale = self.originalImage?.scale ?? output.scale
                let normalizedOut = UIImage(cgImage: rendered, scale: finalScale, orientation: .up)
                self.processedImage = normalizedOut
            } else {
                self.processedImage = output
            }
            print("[FunnyFaceViewModel] Googly eyes processing complete. processedImage size=\(String(describing: processedImage?.size)) token=\(token)")
        } catch {
            self.errorMessage = "Processing failed: \(error.localizedDescription)"
        }
    }
    
    // Apply only overlays (sunglasses / goofy smile) based on the selectedOverlay and selectedFeature
    func applyFilter() async {
        errorMessage = nil
        
        // Ensure at least one effect selected
        guard eyeOverlay != .none || goofyChecked else {
            errorMessage = "No effect selected to apply."
            return
        }
        
        let token: UUID
        if let current = currentProcessingToken {
            token = current
        } else if let t = startProcessingIfAvailable() {
            token = t
        } else {
            print("[FunnyFaceViewModel] applyFilter: unable to start processing (already running or no image)")
            return
        }
        
        guard let input = originalImage ?? inputImage else {
            errorMessage = "Please import an image first."
            isProcessing = false
            currentProcessingToken = nil
            return
        }
        
        print("[FunnyFaceViewModel] Starting filter processing. token=\(token)")
        
        defer {
            if currentProcessingToken == token {
                currentProcessingToken = nil
            }
            isProcessing = false
        }
        
        do {
            let source: UIImage
            if let cg = input.cgImage {
                source = UIImage(cgImage: cg, scale: input.scale, orientation: .up)
            } else if let rendered = input.renderedCGImage() {
                source = UIImage(cgImage: rendered, scale: input.scale, orientation: .up)
            } else {
                source = input
            }
            
            // Apply chosen effects in a single pass derived from the eyeOverlay picker
            let applyGoogly = (eyeOverlay == .googly)
            let applySunglasses = (eyeOverlay == .sunglasses)
            let output = try await FaceProcessor.shared.process(image: source, selectedFeature: selectedFeature, applyGoogly: applyGoogly, applySunglasses: applySunglasses, applyGoofy: goofyChecked)
            
            guard self.currentProcessingToken == token else {
                print("[FunnyFaceViewModel] Discarding stale processing result for token=\(token)")
                return
            }
            
            if let outCG = output.cgImage {
                let finalScale = self.originalImage?.scale ?? output.scale
                let normalizedOut = UIImage(cgImage: outCG, scale: finalScale, orientation: .up)
                self.processedImage = normalizedOut
            } else if let rendered = output.renderedCGImage() {
                let finalScale = self.originalImage?.scale ?? output.scale
                let normalizedOut = UIImage(cgImage: rendered, scale: finalScale, orientation: .up)
                self.processedImage = normalizedOut
            } else {
                self.processedImage = output
            }
            print("[FunnyFaceViewModel] Filter processing complete. processedImage size=\(String(describing: processedImage?.size)) token=\(token)")
        } catch {
            self.errorMessage = "Processing failed: \(error.localizedDescription)"
        }
    }
    
    func reset() {
        // Restore the original image (remove applied processing) and reset selections.
        processedImage = nil
        inputImage = originalImage
        selectedFeature = .all
        // reset overlay and goofy
        eyeOverlay = .googly
        goofyChecked = false
        currentProcessingToken = nil
        isProcessing = false
        errorMessage = nil
    }
}
