import SwiftUI

private struct OpenAIServiceKey: EnvironmentKey {
  static let defaultValue: OpenAIService = OpenAIService(apiKey: "")
}

extension EnvironmentValues {
  var openAIService: OpenAIService {
    get { self[OpenAIServiceKey.self] }
    set { self[OpenAIServiceKey.self] = newValue }
  }
} 