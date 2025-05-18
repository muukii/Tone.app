import SwiftData

public protocol TagType: SwiftData.PersistentModel {
  
  var name: String? { get set }  
  
  func markAsUsed()
  
  init(name: String)
}
