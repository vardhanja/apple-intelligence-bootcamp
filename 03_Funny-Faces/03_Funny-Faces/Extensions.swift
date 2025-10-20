//
//  Extensions.swift
//  03_Funny-Faces
//
//  Created by Ashok Vardhan Jangeti on 20/10/25.
//

import UIKit
import ImageIO

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

// Make renderedCGImage available module-wide so other types (ViewModel, FaceProcessor) can use it.
extension UIImage {
    /// Render UIImage into a CGImage using UIGraphicsImageRenderer as a fallback.
    /// This is internal (module-visible) so callers in the app can access it.
    func renderedCGImage() -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        let renderer = UIGraphicsImageRenderer(size: self.size, format: format)
        let img = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
        return img.cgImage
    }
}
