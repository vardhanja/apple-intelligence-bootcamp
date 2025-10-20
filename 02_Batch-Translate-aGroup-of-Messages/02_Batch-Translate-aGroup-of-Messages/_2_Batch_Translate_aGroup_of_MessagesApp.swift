//
//  _2_Batch_Translate_aGroup_of_MessagesApp.swift
//  02_Batch-Translate-aGroup-of-Messages
//
//  Created by Ashok Vardhan Jangeti on 16/10/25.
//

import SwiftUI

@main
struct _2_Batch_Translate_aGroup_of_MessagesApp: App {
    @State private var viewModel = ViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environment(viewModel)
        }
    }
}
