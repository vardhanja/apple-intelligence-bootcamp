//
//  DetectedObject.swift
//  06_3rd-party-ondevice-models
//
//  Created by Ashok Vardhan Jangeti on 10/11/25.
//

import Foundation

struct DetectedObject: Hashable {
  var label: String
  var confidence: Float
  var boundingBox: CGRect
}
