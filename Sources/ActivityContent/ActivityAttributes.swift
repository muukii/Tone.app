import ActivityKit

public nonisolated struct PlayerActivityAttributes: ActivityAttributes {
  
  public nonisolated struct ContentState: Codable, Hashable {
    
    public let title: String
    public let artist: String?
    public let isPlaying: Bool
    
    public init(
      title: String,
      artist: String? = nil,
      isPlaying: Bool
    ) {
      self.title = title
      self.artist = artist
      self.isPlaying = isPlaying
    }
  }
  
  public let itemId: String
  
  public init(itemId: String) {
    self.itemId = itemId
  }
  
}
