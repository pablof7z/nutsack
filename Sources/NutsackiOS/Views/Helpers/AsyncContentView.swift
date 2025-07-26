import SwiftUI

/// A view that loads content asynchronously and displays it when ready
struct AsyncContentView<Content: View, T>: View {
    let operation: () async -> T
    let content: (T) -> Content
    
    @State private var result: T?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let result = result {
                content(result)
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .task {
            isLoading = true
            result = await operation()
            isLoading = false
        }
    }
}