import SwiftUI
import Translation


struct ContentView: View {
    // MARK: - State Properties
    
    @Environment(ViewModel.self) private var viewModel: ViewModel
    
    @State private var configuration: TranslationSession.Configuration?
        
    @State private var newTaskTitle: String = ""
    
    @State private var isTranslating = false

    @State private var showConfig = false

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Enter a new task...", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTask) // Adds task on hitting return
                    
                    Button("Add", action: addTask)
                        .disabled(newTaskTitle.isEmpty)
                }
                .padding()
                
                // The list of tasks
                List(viewModel.tasks) { task in
                    Text(task.title)
                }
                
                Spacer()
                
                // The main translate button
                Button(action: {
                    showConfig = true
                }) {
                    // Show a loading indicator when busy
                    if isTranslating {
                        ProgressView()
                            .padding(.horizontal)
                    }
                    Label("Translate All", systemImage: "globe")
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("My Tasks")
            .translationTask(configuration) { session in
                Task {
                    await viewModel.translateSequence(using: session)
                }
            }
            .sheet(isPresented: $showConfig) {
                TranslationConfigView(onTranslate: {
                    showConfig = false
                    translateAll()
                })
            }
        }
    }
    
    // MARK: - Methods
    
    /// Adds the text from the input field as a new task.
    func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        viewModel.tasks.append(TaskItem(title: newTaskTitle))
        newTaskTitle = "" // Clear the input field
    }
    
    private func translateAll() {
        configuration = .init(source: viewModel.translateFrom, target: viewModel.translateTo)
    }
}


#Preview {
    ContentView()
}
