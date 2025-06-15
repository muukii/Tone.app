import SwiftData
import Foundation

extension Schemas.V3 {
  
  public enum SegmentKind: String, Codable, CaseIterable {
    case text
    case separator
  }
  
  @Model
  public nonisolated final class Segment: Hashable {
    
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var text: String
    public var kind: String = SegmentKind.text.rawValue
    
    @Relationship(inverse: \Item.segments)
    public var item: Item?
    
    public var segmentKind: SegmentKind {
      get { SegmentKind(rawValue: kind) ?? .text }
      set { kind = newValue.rawValue }
    }
    
    public init(startTime: TimeInterval, endTime: TimeInterval, text: String, kind: SegmentKind = .text) {
      self.startTime = startTime
      self.endTime = endTime
      self.text = text
      self.kind = kind.rawValue
    }
  }
}