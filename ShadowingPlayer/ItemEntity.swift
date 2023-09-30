import SwiftData
import Foundation

@Model
final class ItemEntity {

  @Attribute(.unique)
  var title: String?

  var createdAt: Date

  var audioFileURL: URL?
  var subtitleFileURL: URL?

  init() {    
    self.createdAt = .init()
  }
}

