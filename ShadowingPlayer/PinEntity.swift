import Foundation
import SwiftData

@Model
final class PinEntity {

  @Attribute(.unique)
  var identifier: String

  var createdAt: Date

  var subtitle: String

  var startTime: TimeInterval
  var endTime: TimeInterval

  @Relationship
  var item: ItemEntity?

  init() {

    self.identifier = ""
    self.createdAt = .init()
    self.subtitle = ""
    self.startTime = 0
    self.endTime = 0
  }
}
