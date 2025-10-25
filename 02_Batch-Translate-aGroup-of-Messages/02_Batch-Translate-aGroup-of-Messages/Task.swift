//
//  Task.swift
//  02_Batch-Translate-aGroup-of-Messages
//
//  Created by Ashok Vardhan Jangeti on 16/10/25.
//

import Foundation

// A simple data model for our tasks
struct TaskItem: Identifiable {
    let id: UUID
    var title: String
    
    init(title: String) {
        self.id = UUID()
        self.title = title
    }
    
    init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }
}
