import SwiftUI
import AppService

struct PlaygroundPanel: View {

  @AppStorage("openAIAPIKey") private var openAIAPIKey: String = ""
  @State private var errorMessage: String?
  @State private var responses: [String] = []
  @State private var isLoading: Bool = false
  @State private var source: String = ""
  
  private var openAIService: OpenAIService? {
    guard !openAIAPIKey.isEmpty else { return nil }
    return OpenAIService(apiKey: openAIAPIKey)
  }
  
  var body: some View {
    Form {      
      if let service = openAIService {
        
        TextField("Source", text: $source)
                  
        Button("Generate Response") {
          Task {
            isLoading = true
            errorMessage = nil
            do {
              let response = try await service.createResponse(
                input: [
                  .init(
                    content: [.init(type: "text", text: "\(source)")],
                    role: "user"
                  )
                ]
              )
              print("Response: \(response)")
              
              self.responses = response.sentences.map { $0.sentence }
            } catch {
              print("Error: \(error)")
              errorMessage = error.localizedDescription
            }
            isLoading = false
          }
        }
        .disabled(source.isEmpty || isLoading)
        
        if isLoading {
          ProgressView()
        }

        if !responses.isEmpty {
          ForEach(responses, id: \.self) { response in
            Text(response)
              .padding()
          }
        }
        
        if let error = errorMessage {
          Text("Error: \(error)")
            .foregroundColor(.red)
        }
      } else {
        Text("OpenAI API Key is not set")
      }
    }
  }
} 
