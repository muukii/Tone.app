import SwiftData
import Foundation

extension Schemas.V3 {
  @Model
  public nonisolated final class Item: Hashable {
    
    @Attribute(.unique)
    public var identifier: String?
    
    public var title: String = ""
    
    public var createdAt: Date
    
    /// a relative path from document directory
    public var audioFilePath: String?
        
    @Relationship(deleteRule: .cascade, inverse: \Pin.item)
    public var pinItems: [Pin] = []
    
    public var tags: [Tag] = []
    
    @Relationship(deleteRule: .cascade)
    public var segments: [Segment] = []
         
    public var audioFileRelativePath: RelativePath? {
      audioFilePath.map { .init($0) }
    }

    public var audioFileAbsoluteURL: URL {
      audioFileRelativePath!.absolute(
        basedOn: AbsolutePath(url: URL.documentsDirectory)
      ).url
    }

    func setSegmentData(_ value: StoredSubtitle) throws {
      
      for segment in segments {
        modelContext?.delete(segment)
      }
      
      segments.removeAll()
      
      let newSegments = value.items.map { 
        Segment(
          startTime: $0.startTime,
          endTime: $0.endTime,
          text: $0.text
        )
      }
      
      self.segments.append(contentsOf: newSegments)
                  
    }

    public func segment() throws -> StoredSubtitle {
      let sortedSegments = segments.sorted { $0.startTime < $1.startTime }
      let abstractSegments = sortedSegments.map { segment in
        AbstractSegment(
          startTime: segment.startTime,
          endTime: segment.endTime,
          text: segment.text
        )
      }
      return StoredSubtitle(items: abstractSegments)
    }

    public init() {    
      self.createdAt = .init()
    }
  }
}
