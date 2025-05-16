import SwiftData

public protocol TaggedItem: SwiftData.PersistentModel {
  var tags: [TagEntity] { get set }
}
