import Foundation
import SwiftData
import SwiftSubtitles

@MainActor
public final class Service {
  
  public let modelContainer: ModelContainer

  public init() {

    let databasePath = URL.documentsDirectory.appending(path: "database")
    do {
      // got an error in migration plan
//      let container = try ModelContainer(
//        for: currentSchema,
//        migrationPlan: ServiceSchemaMigrationPlan.self,
//        configurations: .init(url: databasePath)
//      )
      let configuration = ModelConfiguration.init(
        url: databasePath,
        cloudKitDatabase: .none
      )
      let container = try ModelContainer(
        for: currentSchema,
        configurations: configuration
      )
      self.modelContainer = container
    } catch {
      // TODO: delete database if schema mismatches or consider migration
      Log.error("\(error)")
      fatalError()
    }

  }

  public func makePinned(range: PlayingRange, for item: ItemEntity) async throws {
    
    let itemID = item.id

    try await withBackground { [self] in

      let modelContext = ModelContext(modelContainer)
      
      let targetItem = try modelContext.fetch(
        .init(
          predicate: #Predicate<ItemEntity> { [id = itemID] in
            $0.persistentModelID == id
          }
        )
      ).first

      let new = PinEntity()
      new.createdAt = .init()
      new.startCueRawIdentifier = range.startCue.id
      new.endCueRawIdentifier = range.endCue.id
      new.identifier = "\(itemID)\(range.startCue.id)-\(range.endCue.id)"

      guard let targetItem else {
        assertionFailure("not found item")
        return
      }

      new.item = targetItem

      Log.debug("Create pin \(String(describing: new))")

      modelContext.insert(new)
      try modelContext.save()
    }

  }

  public func renameItem(item: ItemEntity, newTitle: String) async throws {
    
    let itemID = item.id
    
    try await withBackground { [self] in
      
      let modelContext = ModelContext(modelContainer)
      
      let targetItem = try modelContext.fetch(
        .init(
          predicate: #Predicate<ItemEntity> { [id = itemID] in
            $0.persistentModelID == id
          }
        )
      ).first
      
      guard let targetItem else {
        return
      }
      
      targetItem.title = newTitle
            
      try modelContext.save()
    }
  }

  public func updateTranscribe(for item: ItemEntity) async throws {

    let result = try await WhisperKitWrapper.run(url: item.audioFileAbsoluteURL)
    try await self.importItem(
      title: item.title,
      audioFileURL: result.audioFileURL,
      segments: result.segments
    )

  }
  
  public func updateTranscription(for item: ItemEntity, with result: OpenAIService.Responses.Transcription) async throws {

    let segments = result.words.map { word in      
      AbstractSegment(startTime: word.start, endTime: word.end, text: word.word)
    }
    
    try await self.importItem(
      title: item.title,
      audioFileURL: item.audioFileAbsoluteURL,
      segments: segments
    )
  }

  public func transcribe(title: String, audioFileURL: URL) async throws {

    let result = try await WhisperKitWrapper.run(url: audioFileURL)
    try await self.importItem(
      title: title,
      audioFileURL: audioFileURL,
      segments: result.segments
    )

  }
  
  public func importItem(
    title: String,
    audioFileURL: URL,
    segments: [AbstractSegment]
  ) async throws {

    let storedSubtitle = StoredSubtitle(items: segments)

    let modelContext = ModelContext(modelContainer)

    let hasSecurityScope = audioFileURL.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        audioFileURL.stopAccessingSecurityScopedResource()
      }
    }

    let target = URL.documentsDirectory.appendingPathComponent("audio", isDirectory: true)

    let fileManager = FileManager.default

    do {

      if fileManager.fileExists(atPath: target.absoluteString) == false {

        try fileManager.createDirectory(
          at: target,
          withIntermediateDirectories: true,
          attributes: nil
        )
      }

      func overwrite(file: URL, to url: URL) throws {

        guard file != url else { return }

        if fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
          try fileManager.removeItem(at: url)
        }

        try fileManager.copyItem(
          at: file,
          to: url
        )

      }

      let audioFileDestinationPath = AbsolutePath(
        url: target.appendingPathComponent(title + "." + audioFileURL.pathExtension)
      )

      do {
        try overwrite(file: audioFileURL, to: audioFileDestinationPath.url)
      }

      try modelContext.transaction {

        let new = ItemEntity()

        new.createdAt = .init()
        new.identifier = title
        new.title = title
        new.audioFilePath =
          audioFileDestinationPath.relative(basedOn: .init(url: URL.documentsDirectory)).rawValue
        try new.setSegmentData(storedSubtitle)

        new.pinItems = []

        modelContext.insert(new)

        let pins = try modelContext.fetch(.init(predicate: #Predicate<PinEntity> { [identifier = new.identifier] in $0.item?.identifier == identifier }))

        for pin in pins {
          pin.item = nil
          modelContext.delete(pin)
        }

      }
    } catch {
      Log.error("Failed to import item: \(error)")
      throw error
    }
  }

  public func importItem(title: String, audioFileURL: URL, subtitleFileURL: URL) async throws {

    guard subtitleFileURL.startAccessingSecurityScopedResource() else {
      Log.error("Failed to start accessing security scoped resource")
      return
    }

    let subtitle = try Subtitles(fileURL: subtitleFileURL, encoding: .utf8)

    subtitleFileURL.stopAccessingSecurityScopedResource()

    try await self.importItem(
      title: title,
      audioFileURL: audioFileURL,
      segments: subtitle.cues.map { .init(cue: $0) }
    )

  }
}
