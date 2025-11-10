//
//  Helpers.swift
//  06_3rd-party-ondevice-models
//
//  Created by Ashok Vardhan Jangeti on 10/11/25.
//

import Foundation

extension CGFloat {
  var roundTwo: String {
    return String(format: "%.2f", self)
  }
}

extension Double {
  var roundTwo: String {
    return String(format: "%.2f", self)
  }
}

extension CGRect {
  func asString() -> String {
    return "origin: (\(self.origin.x.roundTwo), \(self.origin.y.roundTwo))" +
    "size: (\(self.size.width.roundTwo) x \(self.size.height.roundTwo))"
  }
}
