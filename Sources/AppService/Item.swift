
import Foundation

public struct Item: Equatable, Identifiable {

  public let id: String

  public let name: String
  public let audioFileURL: URL
  public let subtitleFileURL: URL

  public init(
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

  #if DEBUG
  public static var example: Self {
    make(name: "example")
  }

  public static var overwhelmed: Self {
    make(name: "overwhelmed - Peter Mckinnon")
  }

  public static var social: Self {
    make(name: "Social Media Has Ruined Photography")
  }
  #endif

  public static func make(name: String) -> Self {

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

  public static func globInBundle() -> [Self] {
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

  public static func globInDocuments() -> [Self] {

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
