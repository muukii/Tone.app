import SwiftData
import Foundation

@Model
public final class ItemEntity: Hashable {

  @Attribute(.unique)
  public var identifier: String?

  public var title: String = ""

  public var createdAt: Date

  /// a relative path from document directory
  public var audioFilePath: String?

  /// a relative path from document directory
  public var subtitleFilePath: String?

  @Relationship(deleteRule: .cascade, inverse: \PinEntity.item)
  public var pinItems: [PinEntity] = []

  public var audioFileRelativePath: RelativePath? {
    audioFilePath.map { .init($0) }
  }

  public var subtitleRelativePath: RelativePath? {
    subtitleFilePath.map { .init($0) }
  }

  public init() {    
    self.createdAt = .init()
  }
}

