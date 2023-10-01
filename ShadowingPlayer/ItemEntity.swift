import SwiftData
import Foundation

@Model
final class ItemEntity: Hashable {

  @Attribute(.unique)
  var title: String?

  var createdAt: Date

  /// a relative path from document directory
  var audioFilePath: String?

  /// a relative path from document directory
  var subtitleFilePath: String?

  var audioFileRelativePath: RelativePath? {
    audioFilePath.map { .init($0) }
  }

  var subtitleRelativePath: RelativePath? {
    subtitleFilePath.map { .init($0) }
  }

  init() {    
    self.createdAt = .init()
  }
}

