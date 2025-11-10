//
//  ImageDisplayView.swift
//  06_3rd-party-ondevice-models
//
//  Created by Ashok Vardhan Jangeti on 10/11/25.
//

import SwiftUI

struct ImageDisplayView: View {
  var image: Image

  var body: some View {
    image
      .resizable()
      .scaledToFit()
      .padding(5.0)
      .border(Color.primary)
      .padding(5.0)
  }
}
