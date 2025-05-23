import SwiftUI
import AppService

struct AnkiBackGenerateView: View {
  let frontText: String
  let service: OpenAIService

  @State private var isLoading = false
  @State private var generatedBack: String = ""
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 24) {
      Text("Front: \(frontText)")
        .font(.headline)
        .padding()

      if isLoading {
        ProgressView("Generating...")
      } else if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      } else if !generatedBack.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Generated Back:")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Text(generatedBack)
            .font(.title2)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
      }

      Button("Backを生成する") {
        generateBack()
      }
      .disabled(isLoading)
    }
    .padding()
    .navigationTitle("Back自動生成")
  }

  private func generateBack() {
    isLoading = true
    errorMessage = nil
    generatedBack = ""
    Task {
      do {
        let input = OpenAIService.ResponseInput(
          content: [
            .init(type: "text", text: "次のFrontに対応するBackを英語で作成してください: \(frontText)")
          ],
          role: "user"
        )
        let sentences = try await service.createResponse(input: [input])
        // ここでは最初のsentenceをbackとして表示
        if let first = sentences.sentences.first {
          generatedBack = first.sentence
        } else {
          errorMessage = "生成結果がありませんでした。"
        }
      } catch {
        errorMessage = "生成に失敗しました: \(error.localizedDescription)"
      }
      isLoading = false
    }
  }
}

#Preview {
  AnkiBackGenerateView(frontText: "I have a pen.", service: OpenAIService(apiKey: "sk-xxxx"))
}
