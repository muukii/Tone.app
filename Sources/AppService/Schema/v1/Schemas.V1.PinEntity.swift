import Foundation
import SwiftData

extension Schemas.V1 {
  @Model
  public final class PinEntity {

    @Attribute(.unique)
    public var identifier: String

    public var createdAt: Date

    public var startCueRawIdentifier: String
    public var endCueRawIdentifier: String

    public var item: ItemEntity?

    public init() {

      self.identifier = ""
      self.createdAt = .init()
      self.startCueRawIdentifier = ""
      self.endCueRawIdentifier = ""
    }
  }
}
