import SwiftData

public protocol TaggedItem: SwiftData.PersistentModel {
  var tags: [TagEntity] { get set }
}

public protocol TagType: SwiftData.PersistentModel {
  
  var name: String { get set }  
  
  func markAsUsed()
  
  init(name: String)
}
