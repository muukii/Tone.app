import Verge
import UserDefaultsSnapshotLib

@Tracking
public struct RootState {
  
  @PrimitiveTrackingProperty
  public var tokens: Tokens
  
  @PrimitiveTrackingProperty
  public fileprivate(set) var openAIService: OpenAIService?
  
}

@MainActor
public final class RootDriver: StoreDriverType {
    
  public let store: Store<RootState, Never>
  
  public let service: Service
  
  public init(openAIAPIToken: String?) {
    self.store = .init(initialState: .init(tokens: .init(openAI: openAIAPIToken.map { 
      .init(value: $0)
    })))
    self.service = .init()
  }

  public func setOpenAIAPIToken(_ token: String) {
    
    guard token.isEmpty == false else {
      store.commit { state in
        state.openAIService = nil
        state.tokens.openAI = nil
      }
      return
    }
    
    store.commit { state in
      state.openAIService = .init(apiKey: token)
      state.tokens.openAI = .init(value: token)
    }
  }
}

@Tracking
public struct Tokens {

  @Tracking
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
