
import Foundation

struct Item_Hashable: Hashable {

  var hashValue: Int {
    body.id.hashValue
  }

  func hash(into hasher: inout Hasher) {
    body.id.hash(into: &hasher)
  }

  let body: ItemEntity

  init(body: ItemEntity) {
    self.body = body
  }

}

struct Item: Equatable, Identifiable {

  let id: String

  let name: String
  let audioFileURL: URL
  let subtitleFileURL: URL

  init(
    identifier: String,
    name: String,
    audioFileURL: URL,
    subtitleFileURL: URL
  ) {
    self.id = identifier
    self.audioFileURL = audioFileURL
    self.subtitleFileURL = subtitleFileURL
    self.name = name
  }

  static var example: Self {
    make(name: "example")
  }

  static var overwhelmed: Self {
    make(name: "overwhelmed - Peter Mckinnon")
  }

  static func make(name: String) -> Self {

    let audioFileURL = Bundle.main.path(forResource: name, ofType: "mp3").map {
      URL(fileURLWithPath: $0)
    }!
    let subtitleFileURL = Bundle.main.path(forResource: name, ofType: "srt").map {
      URL(fileURLWithPath: $0)
    }!
    return .init(
      identifier: name,
      name: name,
      audioFileURL: audioFileURL,
      subtitleFileURL: subtitleFileURL
    )
  }

  static func globInBundle() -> [Self] {
    let bundle = Bundle.main

    let audioFiles = bundle.paths(forResourcesOfType: "mp3", inDirectory: nil)

    let items = audioFiles.map { file in
      
      let base = (file as NSString).deletingPathExtension
      let audioFileURL = URL(fileURLWithPath: file)
      let subtitleFileURL = URL(fileURLWithPath: base + ".srt")

      return Item.init(
        identifier: base,
        name: base,
        audioFileURL: audioFileURL,
        subtitleFileURL: subtitleFileURL
      )
    }

    return items
  }

  static func globInDocuments() -> [Self] {

    let target = URL.documentsDirectory.appendingPathComponent("audio", isDirectory: true)

    var isDirectory = ObjCBool(true)
    guard FileManager.default.fileExists(atPath: target.path(), isDirectory: &isDirectory) else {
      return []
    }

    guard isDirectory.boolValue else {
      assertionFailure("audio directory is not directory")
      return []
    }

    let audioFiles = try! FileManager.default.contentsOfDirectory(
      at: target,
      includingPropertiesForKeys: nil,
      options: .skipsHiddenFiles
    )

    print(audioFiles)

    return []

  }

}
