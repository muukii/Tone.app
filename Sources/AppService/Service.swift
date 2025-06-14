import ConcurrencyTaskManager
import Foundation
import StateGraph
import SwiftData
import SwiftSubtitles

@MainActor
public final class Service {

  public let modelContainer: ModelContainer

  @GraphStored
  private var transcribingItems: [TranscribeWorkItem] = []
  
  public var hasTranscribingItems: Bool {
    !transcribingItems.isEmpty
  }
    
  private let taskManager = TaskManagerActor()

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

      let id = itemID
      let targetItem = try modelContext.fetch(
        .init(
          predicate: #Predicate<ItemEntity> {
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

      let id = itemID
      let targetItem = try modelContext.fetch(
        .init(
          predicate: #Predicate<ItemEntity> {
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

  public func renameTag(tag: TagEntity, newName: String) async throws {

    let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedName.isEmpty else {
      throw ServiceError.invalidInput("Tag name cannot be empty")
    }

    let tagID = tag.id

    try await withBackground { [self] in

      let modelContext = ModelContext(modelContainer)

      let id = tagID
      let targetTag = try modelContext.fetch(
        .init(
          predicate: #Predicate<TagEntity> {
            $0.persistentModelID == id
          }
        )
      ).first

      guard let targetTag else {
        return
      }

      targetTag.name = trimmedName
      targetTag.lastUsedAt = Date()

      try modelContext.save()
    }
  }

  public func deleteTag(_ tag: TagEntity) throws {

    modelContainer.mainContext.delete(tag)

    try modelContainer.mainContext.save()
  }

  public func createTag(name: String) throws -> TagEntity? {

    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedName.isEmpty else {
      throw ServiceError.invalidInput("Tag name cannot be empty")
    }

    do {

      let modelContext = ModelContext(modelContainer)

      // Check if tag already exists
      let existingTags = try modelContext.fetch(
        .init(
          predicate: #Predicate<TagEntity> {
            $0.name == trimmedName
          }
        )
      )

      guard existingTags.isEmpty else {
        Log.error("Tag with name '\(trimmedName)' already exists.")
        return nil
      }

      // Create new tag
      let newTag = TagEntity(name: trimmedName)
      newTag.markAsUsed()

      modelContext.insert(newTag)
      try modelContext.save()

      return newTag
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

  public func updateTranscription(
    for item: ItemEntity,
    with result: OpenAIService.Responses.Transcription
  ) async throws {

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

  public func enqueueTranscribe(target: TargetFile) -> TranscribeWorkItem {
    
    enum TaskKey: TaskKeyType {
      
    }

    let item = TranscribeWorkItem(file: target)

    transcribingItems.append(item)
    
    item.associatedTask = Task {
      await taskManager.task(key: .init(TaskKey.self), mode: .waitInCurrent) { [weak self] in
        do {
          let file = item.file
          
          item.status = .processing
          
          try await self?.transcribe(
            title: file.name,
            audioFileURL: file.url
          )
          
          item.status = .completed
        } catch {
          item.status = .failed
        }     
        
        self?.transcribingItems.removeAll(where: { $0 == item })
      }
    }
       
    return item
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

        let identifier = new.identifier
        let pins = try modelContext.fetch(
          .init(predicate: #Predicate<PinEntity> { $0.item?.identifier == identifier })
        )

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

public nonisolated struct TargetFile: Sendable, Hashable {
  public let name: String
  public let url: URL

  public init(
    name: String,
    url: URL
  ) {
    self.name = name
    self.url = url
  }
}

public final class TranscribeWorkItem: Hashable {

  public static func == (
    lhs: TranscribeWorkItem,
    rhs: TranscribeWorkItem
  ) -> Bool {
    lhs === rhs
  }

  public func hash(into hasher: inout Hasher) {
    ObjectIdentifier(self).hash(into: &hasher)
  }

  enum Status {
    case waiting
    case processing
    case completed
    case failed
  }

  let file: TargetFile

  @GraphStored
  var status: Status = .waiting
  
  var associatedTask: Task<Void, Never>?

  init(file: TargetFile) {
    self.file = file
  }
}

@MainActor
final class AudioImportSession {

  final class TargetFileState: Hashable {

    static func == (
      lhs: AudioImportSession.TargetFileState,
      rhs: AudioImportSession.TargetFileState
    ) -> Bool {
      lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
      ObjectIdentifier(self).hash(into: &hasher)
    }

    enum Status {
      case waiting
      case processing
      case completed
      case failed
    }

    let file: TargetFile

    @GraphStored
    var status: Status = .waiting

    init(file: TargetFile) {
      self.file = file
    }
  }

  @GraphStored
  var targetFiles: [TargetFileState]

  @GraphStored
  var isProcessing: Bool = false

  let service: Service

  init(
    targets: [TargetFile],
    service: Service
  ) {
    self.service = service

    self.targetFiles = targets.map {
      .init(file: $0)
    }

  }

  func startProcessing() {

    guard !isProcessing else {
      return
    }

    self.isProcessing = true

    let files = targetFiles

    Task { [service] in

      for fileStore in files {

        defer {
          fileStore.status = .completed
        }
        do {
          let file = fileStore.file

          fileStore.status = .processing

          try await service.transcribe(
            title: file.name,
            audioFileURL: file.url
          )
        } catch {
          fileStore.status = .failed
        }

      }

      self.isProcessing = false
    }

  }
}
