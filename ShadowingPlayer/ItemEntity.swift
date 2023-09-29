import SwiftData

@Model
final class ItemEntity {

  @Attribute(.unique)
  var identifier: String

  var name: String

  init() {
    self.identifier = ""
    self.name = ""
  }
}

