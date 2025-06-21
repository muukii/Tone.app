import ConcurrencyTaskManager
import Foundation
import StateGraph
import SwiftData
import SwiftSubtitles
import UIKit
import UserNotifications

@MainActor
public final class Service {
  
  public let modelContainer: ModelContainer
  
  @GraphStored
  private var transcribingItems: [TranscribeWorkItem] = []
  
  public var hasTranscribingItems: Bool {
    !transcribingItems.isEmpty
  }
  
  @GraphStored(backed: .userDefaults(key: "selectedWhisperModel"))
  public var selectedWhisperModel: String = "small.en"
  
  @GraphStored(backed: .userDefaults(key: "openAIAPIKey"))
  public var openAIAPIKey: String = ""
  
  @GraphStored(backed: .userDefaults(key: "backgroundTranscriptionNotificationsEnabled"))
  public var backgroundTranscriptionNotificationsEnabled: Bool = false
  
  @GraphStored(backed: .userDefaults(key: "pendingTranscriptions"))
  private var pendingTranscriptionsWrapper: PendingTranscriptionsWrapper = .init(items: [])
  
  public struct TranscriptionProgress {
    public let remainingCount: Int
    public let currentItemTitle: String?
  }
  
  public var transcriptionProgress: TranscriptionProgress {
    let remaining = transcribingItems.filter { $0.status == .waiting || $0.status == .processing }
      .count
    let currentTitle = transcribingItems.first { $0.status == .processing }?.file.name
    
    return TranscriptionProgress(
      remainingCount: remaining,
      currentItemTitle: currentTitle
    )
  }
  
  private let taskManager = TaskManagerActor()
  
  // Background task management
  private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
  
  // Track if we should stop processing due to background time running out
  @GraphStored
  private var shouldStopBackgroundProcessing: Bool = false
  
  // Track if we should stop processing due to background time running out
#if swift(>=6.2)
  @available(iOS 26.0, *)
  public var continuedProcessingTaskManager: TranscriptionBackgroundTaskManager {
    anyContinuedProcessingTaskManager as! TranscriptionBackgroundTaskManager
  }
  private let anyContinuedProcessingTaskManager: AnyObject?
#endif
  
  public init() {
    
#if swift(>=6.2)
    if #available(iOS 26.0, *) {
      self.anyContinuedProcessingTaskManager = TranscriptionBackgroundTaskManager()
      continuedProcessingTaskManager.register()
    } else {
      self.anyContinuedProcessingTaskManager = nil
    }
#endif
    
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
    
    // Set up app lifecycle observers
    setupLifecycleObservers()
    
    // Restore any pending transcriptions
    Task {
      await restorePendingTranscriptions()
    }
    
  }
  
  private func setupLifecycleObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }
  
  @objc private func handleAppDidEnterBackground() {
    Log.debug("App entered background, saving transcription state...")
    savePendingTranscriptions()
  }
  
  @objc private func handleAppWillEnterForeground() {
    Log.debug("App will enter foreground, restoring transcription state...")
    Task {
      await restorePendingTranscriptions()
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
  
  public func insertSeparator(for item: ItemEntity, beforeCueId: String) async throws {
    
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
        assertionFailure("not found item")
        return
      }
      
      // Get the current segments from the item
      let currentSubtitle = try targetItem.segment()
      var segments = currentSubtitle.items
      
      // Find the index of the segment with the given cue ID
      guard let targetIndex = segments.firstIndex(where: { $0.id == beforeCueId }) else {
        Log.error("Could not find segment with id: \(beforeCueId)")
        return
      }
      
      // Get the segment before which we want to insert the separator
      let targetSegment = segments[targetIndex]
      
      // Calculate the position for the separator
      // If there's a previous segment, place the separator between them
      let separatorStartTime: TimeInterval
      let separatorEndTime: TimeInterval
      
      if targetIndex > 0 {
        let previousSegment = segments[targetIndex - 1]
        // Place separator in the middle of the gap
        let gapStart = previousSegment.endTime
        let gapEnd = targetSegment.startTime
        let gapDuration = gapEnd - gapStart
        
        if gapDuration > 0 {
          // There's a gap, place separator in the middle
          separatorStartTime = gapStart + (gapDuration / 2) - 0.001
          separatorEndTime = gapStart + (gapDuration / 2) + 0.001
        } else {
          // No gap, create a minimal separator
          separatorStartTime = gapStart
          separatorEndTime = gapStart + 0.002
        }
      } else {
        // This is the first segment, place separator just before it
        separatorStartTime = max(0, targetSegment.startTime - 0.1)
        separatorEndTime = separatorStartTime + 0.002
      }
      
      // Create the separator segment
      let separator = AbstractSegment(
        startTime: separatorStartTime,
        endTime: separatorEndTime,
        text: "",
        kind: .separator
      )
      
      // Insert the separator before the target segment
      segments.insert(separator, at: targetIndex)
      
      // Update the item with the new segments
      let updatedSubtitle = StoredSubtitle(items: segments)
      try targetItem.setSegmentData(updatedSubtitle)
      
      try modelContext.save()
      
      Log.debug("Inserted separator before segment at \(separatorStartTime)")
    }
  }
  
  public func deleteSeparator(for item: ItemEntity, cueId: String) async throws {
    
    let itemID = item.id
    
    try await withBackground { [self] in
      
      let modelContext = ModelContext(modelContainer)
      let list = FetchDescriptor<ItemEntity>(
        predicate: #Predicate { $0.id == itemID }
      )
      
      guard let targetItem = try modelContext.fetch(list).first else {
        assertionFailure("not found item")
        return
      }
      
      // Get the current segments from the item
      let currentSubtitle = try targetItem.segment()
      var segments = currentSubtitle.items
      
      // Find and remove the separator segment
      if let index = segments.firstIndex(where: {
        $0.id == cueId && $0.kind == .separator
      }) {
        segments.remove(at: index)
        
        // Update the item with the new segments
        let updatedSubtitle = StoredSubtitle(items: segments)
        try targetItem.setSegmentData(updatedSubtitle)
        
        try modelContext.save()
        
        Log.debug("Deleted separator at index \(index)")
      } else {
        Log.warning("Separator with ID \(cueId) not found")
      }
    }
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
    
    let result = try await WhisperKitWrapper.run(
      url: item.audioFileAbsoluteURL, model: selectedWhisperModel)
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
  
  public func transcribe(title: String, audioFileURL: URL, tags: [TagEntity] = []) async throws {
    
#if swift(>=6.2)
    if #available(iOS 26.0, *) {
      do {
        try continuedProcessingTaskManager.submitTask(
          itemTitle: title,
          itemId: UUID().uuidString
        )
      } catch {
        Log.warning("Failed to submit background task: \(error)")
        // Continue with normal transcription
      }
    }
#endif
    
    let result: WhisperKitWrapper.Result
    
#if swift(>=6.2)
    if #available(iOS 26.0, *) {
      
      result = try await WhisperKitWrapper.run(
        url: audioFileURL,
        model: selectedWhisperModel,
        progressHandler: { [continuedProcessingTaskManager] progress in
          continuedProcessingTaskManager.updateProgress(progress)
        },
        shouldContinue: { [continuedProcessingTaskManager] in
          continuedProcessingTaskManager.canContinue
        }
      )
      
      continuedProcessingTaskManager.completeTask(success: true)
    } else {
      result = try await WhisperKitWrapper.run(
        url: audioFileURL,
        model: selectedWhisperModel
      )
    }
#else
    
    result = try await WhisperKitWrapper.run(
      url: audioFileURL,
      model: selectedWhisperModel
    )
    
#endif
    
    try await self.importItem(
      title: title,
      audioFileURL: audioFileURL,
      segments: result.segments,
      tags: tags
    )
    
  }
  
  public func cancelTranscribe() {
    Task {
      await taskManager.cancelAll()
      transcribingItems.removeAll()
      endBackgroundTaskIfNeeded()
    }
  }
  
  // MARK: - Background Task Management
  
  private func beginBackgroundTaskIfNeeded() {
    guard backgroundTaskIdentifier == .invalid else { return }
    
    backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
      withName: "WhisperKit Transcription"
    ) { [weak self] in
      // Called when background time is about to expire
      Log.warning("Background task expiring, stopping transcription...")
      self?.handleBackgroundTaskExpiration()
    }
    
    if backgroundTaskIdentifier != .invalid {
      Log.debug("Started background task for transcription")
      shouldStopBackgroundProcessing = false
      
      // Monitor remaining background time
      Task { [weak self] in
        await self?.monitorBackgroundTime()
      }
    }
  }
  
  private func endBackgroundTaskIfNeeded() {
    guard backgroundTaskIdentifier != .invalid else { return }
    
    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
    backgroundTaskIdentifier = .invalid
    shouldStopBackgroundProcessing = false
    Log.debug("Ended background task")
  }
  
  private func handleBackgroundTaskExpiration() {
    // Signal that we should stop processing
    shouldStopBackgroundProcessing = true
    
    // Cancel current transcription
    Task {
      await taskManager.cancelAll()
      
      // Mark currently processing item as waiting so it can be resumed
      if let processingItem = transcribingItems.first(where: { $0.status == .processing }) {
        processingItem.status = .waiting
      }
      
      endBackgroundTaskIfNeeded()
    }
  }
  
  private func monitorBackgroundTime() async {
    while backgroundTaskIdentifier != .invalid {
      let remainingTime = UIApplication.shared.backgroundTimeRemaining
      
      if remainingTime < 30 && remainingTime != .greatestFiniteMagnitude {
        Log.warning("Less than 30 seconds of background time remaining: \(remainingTime)")
        
        // If we're getting low on time, gracefully stop after current file
        if remainingTime < 10 {
          shouldStopBackgroundProcessing = true
        }
      }
      
      try? await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5 seconds
    }
  }
  
  // MARK: - Persistence
  
  private struct PersistentTranscriptionItem: Codable, Sendable, Equatable {
    let fileName: String
    let fileURL: URL
    let tagNames: [String]
    let status: String // "waiting", "processing", "completed", "failed"
  }
  
  private struct PendingTranscriptionsWrapper: Codable, Sendable, Equatable, UserDefaultsStorable {
    let items: [PersistentTranscriptionItem]
  }
  
  private func savePendingTranscriptions() {
    let pendingItems = transcribingItems.compactMap { item -> PersistentTranscriptionItem? in
      // Only save items that haven't completed
      guard item.status == .waiting || item.status == .processing else {
        return nil
      }
      
      return PersistentTranscriptionItem(
        fileName: item.file.name,
        fileURL: item.file.url,
        tagNames: item.file.tags.compactMap { $0.name },
        status: item.status == .processing ? "waiting" : "waiting" // Reset processing to waiting
      )
    }
    
    pendingTranscriptionsWrapper = PendingTranscriptionsWrapper(items: pendingItems)
    Log.debug("Saved \(pendingItems.count) pending transcriptions")
  }
  
  private func restorePendingTranscriptions() async {    
    let persistedItems = pendingTranscriptionsWrapper.items
    
    // Clear the saved data
    pendingTranscriptionsWrapper = .init(items: [])
    
    Log.debug("Restoring \(persistedItems.count) pending transcriptions")
    
    do {
      for persistedItem in persistedItems {
        // Find matching tags
        let actor = BackgroundModelActor(modelContainer: modelContainer)
        let targetFile = try await actor.perform { modelContext in
          
          let tagSet = persistedItem.tagNames.map { Optional($0) }
          let tags = try modelContext.fetch(
            .init(predicate: #Predicate<TagEntity> { tag in
              tagSet.contains(tag.name)
            })
          )
          
          // Create a new TargetFile and enqueue it
          let targetFile = TargetFile(
            name: persistedItem.fileName,
            url: persistedItem.fileURL,
            tags: tags
          )
          
          return targetFile
        }
        
        _ = enqueueTranscribe(target: targetFile)
      }
    } catch {
      Log.error("Failed to restore pending transcriptions: \(error)")
    }
  }
  
  private func notifyTranscriptionComplete() {
    guard backgroundTranscriptionNotificationsEnabled else { return }
    
    let content = UNMutableNotificationContent()
    content.title = "Transcription Complete"
    content.body = "All audio files have been transcribed successfully."
    content.sound = .default
    
    let request = UNNotificationRequest(
      identifier: "transcription-complete-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        Log.error("Failed to send notification: \(error)")
      }      
    }
    
  }
  
  public func enqueueTranscribe(target: TargetFile, additionalTags: [TagEntity] = [])
  -> TranscribeWorkItem
  {
    
    enum TaskKey: TaskKeyType {
      
    }
    
    let item = TranscribeWorkItem(file: target)
    
    transcribingItems.append(item)
    
    // Start background task if this is the first item
    if transcribingItems.count == 1 {
      beginBackgroundTaskIfNeeded()
    }
    
    item.associatedTask = Task {
      await taskManager.task(key: .init(TaskKey.self), mode: .waitInCurrent) { [weak self] in
        do {
          guard let self else { return }
          
          // Check if we should stop due to background time expiring
          if self.shouldStopBackgroundProcessing {
            Log.warning("Skipping transcription due to background time limit")
            item.status = .waiting  // Mark as waiting so it can be resumed
            return
          }
          
          let file = item.file
          
          item.status = .processing
          
          try await self.transcribe(
            title: file.name,
            audioFileURL: file.url,
            tags: file.tags + additionalTags
          )
          
          item.status = .completed
        } catch {
          item.status = .failed
          Log.error("Transcription failed: \(error)")
          
          // Complete the background task with failure if it was started
#if swift(>=6.2)
          if #available(iOS 26.0, *) {
            self?.continuedProcessingTaskManager.completeTask(success: false)
          }
#endif
        }
        
        self?.transcribingItems.removeAll(where: { $0 == item })
        
        // If no more items to process, end background task
        if self?.transcribingItems.isEmpty == true {
          // Check if we completed transcriptions in background
          if UIApplication.shared.applicationState == .background {
            self?.notifyTranscriptionComplete()
          }
          self?.endBackgroundTaskIfNeeded()
        }
      }
    }
    
    return item
  }
  
  public func importItem(
    title: String,
    audioFileURL: URL,
    segments: [AbstractSegment],
    tags: [TagEntity] = []
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
        
        let itemIdentifier = title
        
        let items = try modelContext.fetch(
          .init(predicate: #Predicate<ItemEntity> { $0.identifier == itemIdentifier })
        )
        
        assert(items.count <= 1)
        
        let targetEntity = items.first ?? ItemEntity()
        
        targetEntity.createdAt = .init()
        targetEntity.identifier = itemIdentifier
        targetEntity.title = title
        targetEntity.audioFilePath =
        audioFileDestinationPath.relative(basedOn: .init(url: URL.documentsDirectory)).rawValue
        try targetEntity.setSegmentData(storedSubtitle)
        
        targetEntity.pinItems = []
        
        // Add tags to the new item
        // We need to fetch the tags from the current model context to ensure they're properly tracked
        for tag in tags {
          // Fetch the tag from the current context by its name
          if let tagName = tag.name {
            let existingTags = try modelContext.fetch(
              .init(predicate: #Predicate<TagEntity> { $0.name == tagName })
            )
            
            if let contextTag = existingTags.first {
              // Use the tag from the current context
              if targetEntity.tags.contains(contextTag) == false {
                targetEntity.tags.append(contextTag)
              }
              contextTag.markAsUsed()
            } else {
              // If tag doesn't exist in this context, create it
              let newTag = TagEntity(name: tagName)
              newTag.markAsUsed()
              modelContext.insert(newTag)
              targetEntity.tags.append(newTag)
            }
          }
        }
        
        modelContext.insert(targetEntity)
        
        let identifier = targetEntity.identifier
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
  
  public func importItem(
    title: String, audioFileURL: URL, subtitleFileURL: URL, tags: [TagEntity] = []
  ) async throws {
    
    guard subtitleFileURL.startAccessingSecurityScopedResource() else {
      Log.error("Failed to start accessing security scoped resource")
      return
    }
    
    let subtitle = try Subtitles(fileURL: subtitleFileURL, encoding: .utf8)
    
    subtitleFileURL.stopAccessingSecurityScopedResource()
    
    try await self.importItem(
      title: title,
      audioFileURL: audioFileURL,
      segments: subtitle.cues.map { .init(cue: $0) },
      tags: tags
    )
    
  }
  
#if targetEnvironment(simulator)
  public func addExampleItems() async throws {
    
    let allEntities = try modelContainer.mainContext.fetch(
      .init(
        predicate: #Predicate<ItemEntity> { _ in
          true
        })
    )
    
    guard allEntities.isEmpty else {
      Log.warning("Example items already exist, skipping import.")
      return
    }
    
    let item = Item.social
    
    try await importItem(
      title: "Example",
      audioFileURL: item.audioFileURL,
      subtitleFileURL: item.subtitleFileURL
    )
    
    let a = Item.overwhelmed
    
    try await importItem(
      title: "overwhelmed",
      audioFileURL: a.audioFileURL,
      subtitleFileURL: a.subtitleFileURL
    )
  }
#endif
  
}

public final class TargetFile: Hashable, Identifiable, Sendable {
  
  public let id = UUID()
  public let name: String
  public let url: URL
  
  @GraphStored
  public var tags: [TagEntity]
  
  public init(
    name: String,
    url: URL,
    tags: [TagEntity] = []
  ) {
    self.name = name
    self.url = url
    self.tags = tags
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  public static func == (lhs: TargetFile, rhs: TargetFile) -> Bool {
    lhs.id == rhs.id
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
