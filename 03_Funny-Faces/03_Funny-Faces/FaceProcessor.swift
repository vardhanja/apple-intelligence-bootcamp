//
//  FaceProcessor.swift
//  03_Funny-Faces
//
//  Created by Ashok Vardhan Jangeti on 20/10/25.
//

import Foundation
import UIKit
import Vision
import CoreGraphics

final class FaceProcessor {
    static let shared = FaceProcessor()
    private init() {}

    /// Process the image and return a new image with effects overlaid.
    func process(image: UIImage, selectedFeature: FacialFeature = .all, applyGoogly: Bool = true, applySunglasses: Bool = true, applyGoofy: Bool = true) async throws -> UIImage {
        // Quick sanity check
        guard image.size.width > 0, image.size.height > 0 else { return image }

        // Ensure we have a CGImage
        guard let cgImage = image.cgImage ?? image.renderedCGImage() else {
            throw NSError(domain: "FaceProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing CGImage for processing"])
        }

        // Debug: log incoming sizes
        print("[FaceProcessor] process called. uiImage.size=\(image.size), uiImage.scale=\(image.scale), cgImage.size=\(cgImage.width)x\(cgImage.height)")

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UIImage, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let orientation = CGImagePropertyOrientation(image.imageOrientation)
                    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

                    // 1) Detect face rectangles first
                    let rectanglesRequest = VNDetectFaceRectanglesRequest()

                    #if targetEnvironment(simulator)
                    if let supported = try? rectanglesRequest.supportedComputeStageDevices, let mainStage = supported[.main] {
                        if let cpuDevice = mainStage.first(where: { device in device.description.contains("CPU") }) {
                            rectanglesRequest.setComputeDevice(cpuDevice, for: .main)
                        }
                    }
                    #endif

                    try handler.perform([rectanglesRequest])

                    // Convert to typed VNFaceObservation array
                    let faceRects = rectanglesRequest.results ?? []

                    print("[FaceProcessor] faceRects.count=\(faceRects.count)")

                    // If no faces, return original image
                    if faceRects.isEmpty {
                        cont.resume(returning: image)
                        return
                    }

                    // 2) Detect landmarks for the detected faces by supplying the face observations
                    let landmarksRequest = VNDetectFaceLandmarksRequest()
                    landmarksRequest.inputFaceObservations = faceRects

                    #if targetEnvironment(simulator)
                    if let supported = try? landmarksRequest.supportedComputeStageDevices, let mainStage = supported[.main] {
                        if let cpuDevice = mainStage.first(where: { device in device.description.contains("CPU") }) {
                            landmarksRequest.setComputeDevice(cpuDevice, for: .main)
                        }
                    }
                    #endif

                    try handler.perform([landmarksRequest])

                    let observations = landmarksRequest.results ?? []

                    // Draw overlays based on landmark observations and flags
                    let output = self.drawOverlays(on: image, cgImage: cgImage, observations: observations, selectedFeature: selectedFeature, applyGoogly: applyGoogly, applySunglasses: applySunglasses, applyGoofy: applyGoofy)
                    cont.resume(returning: output)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func drawOverlays(on image: UIImage, cgImage: CGImage, observations: [VNFaceObservation], selectedFeature: FacialFeature, applyGoogly: Bool, applySunglasses: Bool, applyGoofy: Bool) -> UIImage {
        // Render in UIKit point-space so UIImage.draw(in:) handles orientation correctly.
        // Use renderer.scale = image.scale so drawing maps to device pixels appropriately.
        let pointSize = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)

        let rendered = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: pointSize)

            // Draw the UIImage (respects orientation and scale)
            image.draw(in: rect)

            let cgContext = ctx.cgContext
            let scale = image.scale

            for observation in observations {
                guard let landmarks = observation.landmarks else { continue }

                // Convert face bounding box normalized -> pixel -> points by dividing with scale
                let faceRectPixels = VNImageRectForNormalizedRect(observation.boundingBox, Int(cgImage.width), Int(cgImage.height))
                let faceRectPoints = CGRect(x: faceRectPixels.origin.x / scale,
                                            y: faceRectPixels.origin.y / scale,
                                            width: faceRectPixels.size.width / scale,
                                            height: faceRectPixels.size.height / scale)

                // For each landmark, compute points in point-space and draw conditionally
                // Eyes
                var leftEyePoints: [CGPoint]? = nil
                var rightEyePoints: [CGPoint]? = nil
                if let leftEye = landmarks.leftEye {
                    leftEyePoints = imagePoints(from: leftEye, faceBoundingBox: observation.boundingBox, imageSize: pointSize, imageScale: scale)
                }
                if let rightEye = landmarks.rightEye {
                    rightEyePoints = imagePoints(from: rightEye, faceBoundingBox: observation.boundingBox, imageSize: pointSize, imageScale: scale)
                }

                // Mouth
                var mouthPoints: [CGPoint]? = nil
                if let outer = landmarks.outerLips {
                    mouthPoints = imagePoints(from: outer, faceBoundingBox: observation.boundingBox, imageSize: pointSize, imageScale: scale)
                }
                
                // Decide which features to draw based on selectedFeature and flags
                let shouldDoLeftEye = applyGoogly && (selectedFeature == .all || selectedFeature == .leftEye)
                let shouldDoRightEye = applyGoogly && (selectedFeature == .all || selectedFeature == .rightEye)
                let shouldDoMouthForGoofy = applyGoofy && (selectedFeature == .all || selectedFeature == .mouth)
                let shouldDoSunglasses = applySunglasses && (selectedFeature == .all || selectedFeature == .leftEye || selectedFeature == .rightEye)

                if shouldDoLeftEye, let points = leftEyePoints {
                    drawGooglyEye(for: points, faceRect: faceRectPoints, in: cgContext)
                }
                if shouldDoRightEye, let points = rightEyePoints {
                    drawGooglyEye(for: points, faceRect: faceRectPoints, in: cgContext)
                }

                // Optionally draw pupils (if present) unaffected by selection for subtlety
                if let leftPupil = landmarks.leftPupil {
                    let points = imagePoints(from: leftPupil, faceBoundingBox: observation.boundingBox, imageSize: pointSize, imageScale: scale)
                    drawSmallPupil(for: points, in: cgContext)
                }
                if let rightPupil = landmarks.rightPupil {
                    let points = imagePoints(from: rightPupil, faceBoundingBox: observation.boundingBox, imageSize: pointSize, imageScale: scale)
                    drawSmallPupil(for: points, in: cgContext)
                }

                // Sunglasses drawing (if requested)
                if shouldDoSunglasses {
                    switch selectedFeature {
                    case .leftEye:
                        if let l = leftEyePoints {
                            drawSunglasses(leftEye: l, rightEye: nil, faceRect: faceRectPoints, in: cgContext)
                        }
                    case .rightEye:
                        if let r = rightEyePoints {
                            drawSunglasses(leftEye: nil, rightEye: r, faceRect: faceRectPoints, in: cgContext)
                        }
                    default:
                        // .all: prefer both lenses when available
                        if let l = leftEyePoints, let r = rightEyePoints {
                            drawSunglasses(leftEye: l, rightEye: r, faceRect: faceRectPoints, in: cgContext)
                        } else if let l = leftEyePoints {
                            drawSunglasses(leftEye: l, rightEye: nil, faceRect: faceRectPoints, in: cgContext)
                        } else if let r = rightEyePoints {
                            drawSunglasses(leftEye: nil, rightEye: r, faceRect: faceRectPoints, in: cgContext)
                        }
                    }
                }

                // Goofy smile (if requested)
                if shouldDoMouthForGoofy, let m = mouthPoints {
                    drawGoofySmile(for: m, in: cgContext)
                }

                // If user selected only mouth and no goofy applied, emphasize the mouth
                // Only draw the highlight when the user explicitly selected the mouth feature
                // and goofy was not requested. Previously this also triggered for `.all`, which
                // could produce an unexpected small colored rectangle when goofy was unchecked.
                if !applyGoofy && selectedFeature == .mouth, let m = mouthPoints {
                    drawHighlight(for: m, color: UIColor.systemPink.withAlphaComponent(0.35), in: cgContext)
                }
            }
        }

        // Return the rendered UIImage (image.draw respected orientation) and ensure .up orientation
        guard let outCG = rendered.cgImage else { return image }
        // Re-render the CGImage into a renderer that uses the original image scale to ensure
        // the final UIImage is displayed correctly by SwiftUI.
        let finalFormat = UIGraphicsImageRendererFormat()
        finalFormat.scale = image.scale
        finalFormat.opaque = false
        let finalRenderer = UIGraphicsImageRenderer(size: rendered.size, format: finalFormat)
        let finalRendered = finalRenderer.image { _ in
            UIImage(cgImage: outCG, scale: image.scale, orientation: .up).draw(in: CGRect(origin: .zero, size: rendered.size))
        }

        guard let finalCG = finalRendered.cgImage else { return image }
        let final = UIImage(cgImage: finalCG, scale: image.scale, orientation: .up)
        print("[FaceProcessor] returning final image size=\(final.size) scale=\(final.scale) orientation=\(final.imageOrientation.rawValue)")
        return final
    }

    // MARK: - Overlay drawing helpers
    private func drawSunglasses(leftEye: [CGPoint]?, rightEye: [CGPoint]?, faceRect: CGRect, in context: CGContext) {
        // Compute bounding boxes for provided eye points
        func box(_ pts: [CGPoint]?) -> CGRect? {
            guard let pts = pts, !pts.isEmpty else { return nil }
            return boundingBox(for: pts)
        }
        let leftBox = box(leftEye)
        let rightBox = box(rightEye)

        context.saveGState()
        UIColor.black.setFill()
        UIColor.black.setStroke()

        // Draw circular lenses
        if let l = leftBox, let r = rightBox {
            let lCenter = CGPoint(x: l.midX, y: l.midY)
            let rCenter = CGPoint(x: r.midX, y: r.midY)

            // radius based on eye size but limited relative to face size
            let faceMax = max(faceRect.width, faceRect.height)
            let baseRadiusL = max(l.width, l.height) * 0.9
            let baseRadiusR = max(r.width, r.height) * 0.9
            let maxAllowed = max(faceMax * 0.06, faceMax * 0.25)
            let radiusL = min(maxAllowed, max(baseRadiusL, faceMax * 0.04))
            let radiusR = min(maxAllowed, max(baseRadiusR, faceMax * 0.04))

            // Draw lenses
            let leftCircle = CGRect(x: lCenter.x - radiusL, y: lCenter.y - radiusL, width: radiusL * 2, height: radiusL * 2)
            let rightCircle = CGRect(x: rCenter.x - radiusR, y: rCenter.y - radiusR, width: radiusR * 2, height: radiusR * 2)
            let leftPath = UIBezierPath(ovalIn: leftCircle)
            let rightPath = UIBezierPath(ovalIn: rightCircle)
            leftPath.fill()
            rightPath.fill()

            // Draw bridge between circles as a rounded line (stroke) connecting edge points
            let bridgePath = UIBezierPath()
            bridgePath.move(to: CGPoint(x: lCenter.x + radiusL * 0.6, y: lCenter.y))
            bridgePath.addLine(to: CGPoint(x: rCenter.x - radiusR * 0.6, y: rCenter.y))
            bridgePath.lineWidth = max(6.0, min(radiusL, radiusR) * 0.5)
            bridgePath.lineCapStyle = .round
            UIColor.black.setStroke()
            bridgePath.stroke()

            // subtle highlight on left lens
            UIColor.white.withAlphaComponent(0.08).setFill()
            let shine = CGRect(x: lCenter.x - radiusL * 0.6, y: lCenter.y - radiusL * 0.9, width: radiusL * 0.6, height: radiusL * 0.25)
            UIBezierPath(roundedRect: shine, cornerRadius: shine.height/2).fill()

        } else if let l = leftBox {
            let lCenter = CGPoint(x: l.midX, y: l.midY)
            let faceMax = max(faceRect.width, faceRect.height)
            let baseRadiusL = max(l.width, l.height) * 0.9
            let radiusL = min(faceMax * 0.25, max(baseRadiusL, faceMax * 0.04))
            let leftCircle = CGRect(x: lCenter.x - radiusL, y: lCenter.y - radiusL, width: radiusL * 2, height: radiusL * 2)
            UIBezierPath(ovalIn: leftCircle).fill()
            UIColor.white.withAlphaComponent(0.08).setFill()
            let shine = CGRect(x: lCenter.x - radiusL * 0.6, y: lCenter.y - radiusL * 0.9, width: radiusL * 0.6, height: radiusL * 0.25)
            UIBezierPath(roundedRect: shine, cornerRadius: shine.height/2).fill()

        } else if let r = rightBox {
            let rCenter = CGPoint(x: r.midX, y: r.midY)
            let faceMax = max(faceRect.width, faceRect.height)
            let baseRadiusR = max(r.width, r.height) * 0.9
            let radiusR = min(faceMax * 0.25, max(baseRadiusR, faceMax * 0.04))
            let rightCircle = CGRect(x: rCenter.x - radiusR, y: rCenter.y - radiusR, width: radiusR * 2, height: radiusR * 2)
            UIBezierPath(ovalIn: rightCircle).fill()
            UIColor.white.withAlphaComponent(0.08).setFill()
            let shine = CGRect(x: rCenter.x - radiusR * 0.6, y: rCenter.y - radiusR * 0.9, width: radiusR * 0.6, height: radiusR * 0.25)
            UIBezierPath(roundedRect: shine, cornerRadius: shine.height/2).fill()
        }

        context.restoreGState()
    }

    private func drawGoofySmile(for mouthPoints: [CGPoint], in context: CGContext) {
        guard !mouthPoints.isEmpty else { return }
        let box = boundingBox(for: mouthPoints)
        if box.isEmpty { return }

        // Compute smile path from leftmost to rightmost mouth points with a deep control point below
        let left = CGPoint(x: box.minX, y: box.midY)
        let right = CGPoint(x: box.maxX, y: box.midY)
        let controlDown = box.height * 2.0
        let control = CGPoint(x: box.midX, y: box.midY + controlDown)

        let path = UIBezierPath()
        path.move(to: left)
        path.addQuadCurve(to: right, controlPoint: control)

        // Thick stroked smile
        UIColor.systemPink.setStroke()
        path.lineWidth = max(6.0, box.height * 0.4)
        path.lineCapStyle = .round
        path.stroke()

        // Tongue/fill - fill a rounded shape beneath the curve
        let fillPath = UIBezierPath()
        fillPath.move(to: left)
        fillPath.addQuadCurve(to: right, controlPoint: control)
        fillPath.addLine(to: CGPoint(x: right.x, y: right.y + box.height*0.6))
        fillPath.addLine(to: CGPoint(x: left.x, y: left.y + box.height*0.6))
        fillPath.close()
        UIColor.systemRed.withAlphaComponent(0.7).setFill()
        fillPath.fill()
    }

    private func drawHighlight(for points: [CGPoint], color: UIColor, in context: CGContext) {
        guard !points.isEmpty else { return }
        let box = boundingBox(for: points).insetBy(dx: -4, dy: -4)
        let path = UIBezierPath(roundedRect: box, cornerRadius: min(12, box.height/3))
        color.setFill()
        path.fill()
    }

    // Convert landmark normalized points into pixel coordinates (image pixel buffer)
    private func imagePointsPixels(from landmark: VNFaceLandmarkRegion2D, faceBoundingBox: CGRect, imagePixelSize: CGSize) -> [CGPoint] {
        return landmark.normalizedPoints.map { p in
            let normalizedX = faceBoundingBox.origin.x + CGFloat(p.x) * faceBoundingBox.size.width
            let normalizedY = faceBoundingBox.origin.y + CGFloat(p.y) * faceBoundingBox.size.height
            let x = normalizedX * imagePixelSize.width
            let y = (1 - normalizedY) * imagePixelSize.height
            return CGPoint(x: x, y: y)
        }
    }

    // Convert landmark normalized points (relative to face bounding box) into pixel coordinates
    private func imagePoints(from landmark: VNFaceLandmarkRegion2D, faceBoundingBox: CGRect, imageSize: CGSize, imageScale: CGFloat) -> [CGPoint] {
        // Backward compatible wrapper that maps to point coordinates using the provided imageScale
        let pixelPoints = imagePointsPixels(from: landmark, faceBoundingBox: faceBoundingBox, imagePixelSize: CGSize(width: imageSize.width * imageScale, height: imageSize.height * imageScale))
        // Convert pixel points back to point-space by dividing by scale
        return pixelPoints.map { CGPoint(x: $0.x / imageScale, y: $0.y / imageScale) }
    }

    // Compute bounding box for a list of points using min/max(by:)
    private func boundingBox(for points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        let minX = points.min(by: { $0.x < $1.x })?.x ?? 0
        let minY = points.min(by: { $0.y < $1.y })?.y ?? 0
        let maxX = points.max(by: { $0.x < $1.x })?.x ?? 0
        let maxY = points.max(by: { $0.y < $1.y })?.y ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // Draw a large white oval covering the eye points and a smaller black pupil offset for a googly look
    private func drawGooglyEye(for points: [CGPoint], faceRect: CGRect, in context: CGContext) {
        guard !points.isEmpty else { return }
        let eyeRect = boundingBox(for: points)
        if eyeRect.isEmpty { return }

        let center = CGPoint(x: eyeRect.midX, y: eyeRect.midY)
        // Base radius on eye size but also clamp relative to face size to avoid runaway growth
        let baseRadius = max(eyeRect.width, eyeRect.height) * 1.6
        let faceMax = max(faceRect.width, faceRect.height)
        // Clamp to between baseRadius and 0.6 * faceMax
        let maxAllowed = max( max(baseRadius, faceMax * 0.12), faceMax * 0.6 )
        let radius = min(baseRadius * 1.2, maxAllowed)

        // White outer circle
        let whiteRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let whitePath = UIBezierPath(ovalIn: whiteRect)
        UIColor.white.setFill()
        whitePath.fill()
        UIColor.black.setStroke()
        whitePath.lineWidth = 2
        whitePath.stroke()

        // Pupil (slightly offset)
        let pupilRadius = max(radius * 0.25, radius * 0.35)
        // offset based on eyeRect center to make googly look
        let pupilOffset = CGPoint(x: radius * 0.15, y: -radius * 0.08)
        let pupilCenter = CGPoint(x: center.x + pupilOffset.x, y: center.y + pupilOffset.y)
        let pupilRect = CGRect(x: pupilCenter.x - pupilRadius, y: pupilCenter.y - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2)
        let pupilPath = UIBezierPath(ovalIn: pupilRect)
        UIColor.black.setFill()
        pupilPath.fill()
    }

    // Optional: draw a small pupil from pupil landmarks (if present)
    private func drawSmallPupil(for points: [CGPoint], in context: CGContext) {
        guard !points.isEmpty else { return }
        let pbox = boundingBox(for: points)
        if pbox.isEmpty { return }
        let center = CGPoint(x: pbox.midX, y: pbox.midY)
        let radius = max(pbox.width, pbox.height) * 1.5
        let pupilRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let path = UIBezierPath(ovalIn: pupilRect)
        UIColor.black.setFill()
        path.fill()
    }

    // Adjust orientation mapping borrowed from ImageViewModel to keep final UIImage oriented like input
    private func adjustOrientation(orient: UIImage.Orientation) -> UIImage.Orientation {
        switch orient {
        case .up: return .downMirrored
        case .upMirrored: return .up
        case .down: return .upMirrored
        case .downMirrored: return .down
        case .left: return .rightMirrored
        case .rightMirrored: return .left
        case .right: return .leftMirrored
        case .leftMirrored: return .right
        @unknown default: return orient
        }
    }
}
