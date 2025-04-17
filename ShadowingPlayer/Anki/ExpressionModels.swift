import SwiftData
import Foundation

@Model
public final class ExpressionTag {
  
  @Attribute(.unique)
  public var identifier: String
    
  public var name: String = ""
  
  @Relationship(deleteRule: .cascade)
  public var expressions: [ExpressionItem] = []
  
  public init() {   
    self.identifier = UUID().uuidString
  }
  
}

@Model public final class ExpressionItem {
  
  @Attribute(.unique)
  public var identifier: String
  
  @Relationship(deleteRule: .cascade)
  public var tags: [ExpressionTag] = []
  
  public var title: String = ""
  
  public var input: String = ""
  public var meaning: String = ""
  public var partsOfSpeech: String = ""
  public var ipa: String = ""
  public var synonyms: [String] = []
  public var sentences: [String] = []

  public init(input: String) {
    self.identifier = UUID().uuidString
    self.input = input
  }
  
}

final class ExpressionService {
  
  init() {
    
  }
  
  private func createModelContainer() -> ModelContainer {
    let container = try! ModelContainer(for: ExpressionTag.self, ExpressionItem.self)
    return container
  }

}
