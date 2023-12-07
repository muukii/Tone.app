import Foundation
import SwiftData

@Model
public final class PinEntity {

  @Attribute(.unique)
  public var identifier: String

  public var createdAt: Date

  public var subtitle: String

  public var startTime: TimeInterval
  public var endTime: TimeInterval

  @Relationship
  public var item: ItemEntity?

  public init() {

    self.identifier = ""
    self.createdAt = .init()
    self.subtitle = ""
    self.startTime = 0
    self.endTime = 0
  }
}
