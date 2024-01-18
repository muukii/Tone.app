import SwiftData
import Foundation

extension Schemas.V2 {
  @Model
  public final class ItemEntity: Hashable {
    
    @Attribute(.unique)
    public var identifier: String?
    
    public var title: String = ""
    
    public var createdAt: Date
    
    /// a relative path from document directory
    public var audioFilePath: String?
        
    @Relationship(deleteRule: .cascade, inverse: \PinEntity.item)
    public var pinItems: [PinEntity] = []
    
    public var audioFileRelativePath: RelativePath? {
      audioFilePath.map { .init($0) }
    }

    public var audioFileAbsoluteURL: URL {
      audioFileRelativePath!.absolute(
        basedOn: AbsolutePath(url: URL.documentsDirectory)
      ).url
    }

    internal var subtitleData: Data?

    func setSegmentData(_ value: StoredSubtitle) throws {
      self.subtitleData = try value.encode()
    }

    public func segment() throws -> StoredSubtitle {
      guard let subtitleData else {
        throw ServiceError.notFoundRequiredValue
      }
      return try StoredSubtitle.init(data: subtitleData)
    }

    public init() {    
      self.createdAt = .init()
    }
  }
}
