import UserDefaultsSnapshotLib
import Foundation
import StateGraph

@MainActor
public final class RootDriver {
  
  @GraphStored
  public var tokens: Tokens
  
  public var openAIService: OpenAIService? {
    _openAIService
  }
  
  @GraphStored
  private /*fileprivate(set)*/ var _openAIService: OpenAIService?
      
  public let service: Service
  
  public init() {
    self.service = .init()
    let openAIAPIToken = service.openAIAPIKey.isEmpty ? nil : service.openAIAPIKey
    self.tokens = .init(openAI: openAIAPIToken.map { .init(value: $0) })
    self._openAIService = openAIAPIToken.map { .init(apiKey: $0) }
  }

  public func setOpenAIAPIToken(_ token: String) {
    
    service.openAIAPIKey = token
    
    guard token.isEmpty == false else {
      _openAIService = nil
      tokens.openAI = nil      
      return
    }
    
    _openAIService = .init(apiKey: token)
    tokens.openAI = .init(value: token)    
  }
}

public struct Tokens {

  public struct OpenAI {
    public let value: String
    
    init(value: String) {
      self.value = value
    }
  }

  public var openAI: OpenAI?

  init(openAI: OpenAI? = nil) {
    self.openAI = openAI
  }
}
