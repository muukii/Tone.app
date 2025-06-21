import Foundation
import SwiftData

extension Schemas.V2 {
  @Model
  public final class Pin: Identifiable {

    @Attribute(.unique)
    public var identifier: String

    public var createdAt: Date

    public var startCueRawIdentifier: String
    public var endCueRawIdentifier: String

    public var item: Item?

    public init() {

      self.identifier = ""
      self.createdAt = .init()
      self.startCueRawIdentifier = ""
      self.endCueRawIdentifier = ""
    }
  }
}
