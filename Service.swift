import Foundation

class Service {
  let openAIService: OpenAIService
  
  init(apiKey: String) {
    self.openAIService = OpenAIService(apiKey: apiKey)
  }
} 