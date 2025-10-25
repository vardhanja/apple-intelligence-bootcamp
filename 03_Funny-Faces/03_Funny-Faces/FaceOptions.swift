//
//  FaceOptions.swift
//  03_Funny-Faces
//
//  Created by Ashok Vardhan Jangeti on 20/10/25.
//

import Foundation
import SwiftUI

enum FacialFeature: String, CaseIterable, Identifiable, Hashable {
    case leftEye = "Left Eye"
    case rightEye = "Right Eye"
    case mouth = "Mouth"
    case all = "All"

    var id: String { rawValue }
}

enum EyeOverlay: String, CaseIterable, Identifiable, Hashable {
    case googly = "Googly Eyes"
    case sunglasses = "Sunglasses"

    var id: String { rawValue }
}
