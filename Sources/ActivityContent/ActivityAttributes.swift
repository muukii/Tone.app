import ActivityKit

public struct MyActivityAttributes: ActivityAttributes {
  
  public struct ContentState: Codable, Hashable {
    
    public let text: String
    
    public init(text: String) {
      self.text = text
    }
  }
  
  public init() {
    
  }
  
}
