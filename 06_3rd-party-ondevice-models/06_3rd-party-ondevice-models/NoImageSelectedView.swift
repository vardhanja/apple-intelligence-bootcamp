//
//  NoImageSelectedView.swift
//  06_3rd-party-ondevice-models
//
//  Created by Ashok Vardhan Jangeti on 10/11/25.
//

import SwiftUI

struct NoImageSelectedView: View {
  var body: some View {
    Image(systemName: "photo.on.rectangle.angled")
      .resizable()
      .scaledToFit()
      .frame(width: 300, height: 300)
      .foregroundColor(.gray)
  }
}

#Preview {
  NoImageSelectedView()
}
