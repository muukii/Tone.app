import SwiftData
import Foundation

@Model
public final class AnkiBook {
  
  @Attribute(.unique)
  public var identifier: String
    
  public var name: String = ""
  
  @Relationship(deleteRule: .cascade, inverse: \AnkiItem.book)
  public var items: [AnkiItem] = []
  
  public init() {   
    self.identifier = UUID().uuidString
  }
  
}

@Model public final class AnkiItem {
  
  @Attribute(.unique)
  public var identifier: String
  
  public var book: AnkiBook?
  
  public var title: String = ""
  
  public var input: String = ""
  public var meaning: String = ""
  public var partsOfSpeech: String = ""
  public var ipa: String = ""
  public var synonyms: [String] = []
  public var sentences: [String] = []

  public init() {
    self.identifier = UUID().uuidString
  }
  
}

final class AnkiService {
  
  init() {
    
  }
  
  private func createModelContainer() -> ModelContainer {
    let container = try! ModelContainer(for: AnkiBook.self, AnkiItem.self)
    return container
  }
  
  // JSON import functionality
  struct AnkiItemJSON: Codable {
    var input: String
    var meaning: String
    var partsOfSpeech: String
    var ipa: String
    var synonyms: [String]
    var sentences: [String]
  }
  
  /// Imports Anki items from JSON data
  /// - Parameters:
  ///   - jsonData: Raw JSON data to import
  ///   - book: The AnkiBook to add items to (will create a new book if nil)
  ///   - modelContext: The SwiftData model context
  /// - Returns: The number of items imported
  @MainActor
  @discardableResult  
  func importFromJSON(
    _ jsonData: Data
  ) throws -> Int {
    
    let modelContainer = createModelContainer()
    let modelContext = modelContainer.mainContext
    
    let decoder = JSONDecoder()
    let items = try decoder.decode([AnkiItemJSON].self, from: jsonData)
    
    let targetBook = AnkiBook()
    targetBook.name = targetBook.name.isEmpty ? "Imported Vocabulary" : targetBook.name
    
    modelContext.insert(targetBook)
        
    for jsonItem in items {
      let ankiItem = AnkiItem()
      ankiItem.input = jsonItem.input
      ankiItem.meaning = jsonItem.meaning
      ankiItem.partsOfSpeech = jsonItem.partsOfSpeech
      ankiItem.ipa = jsonItem.ipa
      ankiItem.synonyms = jsonItem.synonyms
      ankiItem.sentences = jsonItem.sentences
      ankiItem.title = jsonItem.input
      
      ankiItem.book = targetBook
      targetBook.items.append(ankiItem)
      modelContext.insert(ankiItem)
    }
    
    try modelContext.save()
    return items.count
  }
}
