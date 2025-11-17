//
//  ObjectOverlayView.swift
//  06_3rd-party-ondevice-models
//
//  Created by Ashok Vardhan Jangeti on 10/11/25.
//

import SwiftUI
import Vision

struct ObjectOverlayView: View {
  var object: DetectedObject
  var lineColor: Color = .red

  var body: some View {
    GeometryReader { proxy in
      let adjustedRect = VNImageRectForNormalizedRect(
        object.boundingBox,
        Int(proxy.size.width),
        Int(proxy.size.height)
      )

      let xa1 = adjustedRect.origin.x
      let ya1 = proxy.size.height - adjustedRect.origin.y
      let xa2 = adjustedRect.origin.x + adjustedRect.width
      let ya2 = proxy.size.height - (adjustedRect.origin.y + adjustedRect.height)
      Path { path in
        path.move(to: .init(x: xa1, y: ya1))
        path.addLine(to: .init(x: xa1, y: ya2))
        path.addLine(to: .init(x: xa2, y: ya2))
        path.addLine(to: .init(x: xa2, y: ya1))
        path.closeSubpath()
      }
      .stroke(lineColor, lineWidth: 2.0)
      let textX = min(xa1, xa2)
      let textY = min(ya1, ya2)
      Text(object.label)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        .offset(x: textX, y: textY)
        .padding(2.0)
    }  }
}

#Preview {
  let object = DetectedObject(
    label: "test",
    confidence: 0.3521,
    boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.1, height: 0.1)
  )
  ObjectOverlayView(object: object)
}
