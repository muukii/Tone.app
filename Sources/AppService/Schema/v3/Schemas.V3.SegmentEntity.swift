import SwiftData
import Foundation

extension Schemas.V3 {
  @Model
  public nonisolated final class Segment: Hashable {
    
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var text: String
    
    @Relationship(inverse: \Item.segments)
    public var item: Item?
    
    public init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
      self.startTime = startTime
      self.endTime = endTime
      self.text = text
    }
  }
}