//
//  ChatView.swift
//  07_car-help-gpt
//
//  Created by Ashok Vardhan Jangeti on 17/11/25.
//

import SwiftUI

struct ChatView: View {
  
  var client = GPTClient(
    model: .gpt35Turbo,
    context: .makeContext(
      "You are CarHelpGPT, an assistant specialized in diagnosing car problems, suggesting maintenance, repair steps, parts, and vehicle improvement ideas. Provide clear, safe, and practical automotive guidance.",
      "Only answer questions that are directly related to cars, vehicles, or vehicle components (for example: engine, brakes, transmission, tires, suspension, electronics, maintenance, diagnostics, upgrades).",
      "If a user asks about non-car topics (medical, legal, IT, or casual conversation), politely refuse with: \"I'm sorry, I can only help with car-related questions. For other topics, please consult an appropriate expert.\"",
      "When refusing, be brief, do not offer off-topic troubleshooting, and suggest the correct resource type (for example: 'consult a medical professional' or 'consult an IT support specialist')."
    )
  )
  
  @State var messages: [GPTMessage] = [
    GPTMessage(role: .assistant, content: "Welcome to CarHelpGPT — ask me about car problems, maintenance, diagnostics, or improvements.")
  ]
  @State var inputText: String = ""
  @State var isLoading = false
  @State var textEditorHeight: CGFloat = 36
  
  var body: some View {
    NavigationView {
      VStack {
        messagesScrollView
        inputMessageView
      }
      .navigationTitle("CarHelpGPT")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(trailing: Button("New") {
        messages = messages.count > 0 ? [messages[0]] : []
      }.disabled(messages.count < 2))
    }
  }
  
  var messagesScrollView: some View {
    ScrollView {
      VStack(spacing: 10) {
        ForEach(messages, id: \.self) { message in
          if (message.role == .user) {
            Text(message.content)
              .padding()
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(10)
              .frame(maxWidth: .infinity, alignment: .trailing)
          } else {
            Text(message.content)
              .padding()
              .background(Color.gray.opacity(0.1))
              .cornerRadius(10)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding()
    }
  }
  
  var inputMessageView: some View {
    HStack {
      TextField("Ask about your car — problem, maintenance, or improvement...", text: $inputText, axis: .vertical)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding()
      
      if isLoading {
        ProgressView()
          .padding()
      }
      
      Button(action: sendMessage) {
        Text("Submit")
      }
      .disabled(inputText.isEmpty || isLoading)
      .padding()
    }
  }
  
  private func sendMessage() {
    isLoading = true
    
    Task {
      let message = GPTMessage(role: .user, content: inputText)
      messages.append(message)
      
      do {
        let response = try await client.sendChats(messages)
        isLoading = false
        
        guard let reply = response.choices.first?.message else {
          print("API error! There weren't any choices despite a successful response")
          return
        }
        messages.append(reply)
        inputText.removeAll()
        
      } catch {
        isLoading = false
        print("Got an error: \(error)")
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ChatView()
  }
}
