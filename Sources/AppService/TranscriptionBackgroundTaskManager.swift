import BackgroundTasks
import Foundation
import StateGraph

@available(iOS 26.0, *)
public nonisolated final class TranscriptionBackgroundTaskManager: Sendable {

  public static let taskIdentifier = "app.muukii.tone.transcription"

  @GraphStored
  public var isTranscribingInBackground: Bool = false

  @GraphStored
  public var currentTaskId: String? = nil

  @GraphStored
  private var currentTask: BGContinuedProcessingTask? = nil
  
  @GraphStored
  private var shouldContinue: Bool = true

  @MainActor
  private var isRegistered: Bool = false

  public init() {}

  /// Register the background task handler
  @MainActor
  public func register() {
    guard !isRegistered else { return }
    isRegistered = true

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: Self.taskIdentifier,
      using: nil,
      launchHandler: { [weak self] task in
        guard let task = task as? BGContinuedProcessingTask else {
          task.setTaskCompleted(success: false)
          return
        }
        self?.handleBackgroundTask(task)
      }
    )
  }

  /// Submit a background task for transcription
  public func submitTask(itemTitle: String, itemId: String) throws {
    let request = BGContinuedProcessingTaskRequest(
      identifier: Self.taskIdentifier,
      title: "Transcribing: \(itemTitle)",
      subtitle: "Preparing..."
    )

    // Enable GPU for WhisperKit ML processing
    if BGTaskScheduler.supportedResources.contains(.gpu) {
      request.requiredResources = .gpu
    }

    // Use immediate fail strategy - if system can't run it now, we'll handle it in foreground
    request.strategy = .queue

    try BGTaskScheduler.shared.submit(request)
    currentTaskId = itemId
    isTranscribingInBackground = true
  }

  /// Update task progress
  public func updateProgress(_ progress: Double, subtitle: String? = nil) {
    guard let task = currentTask else { return }

    task.progress.totalUnitCount = 100
    task.progress.completedUnitCount = Int64(progress * 100)

    if let subtitle = subtitle {
      task.updateTitle(task.title, subtitle: subtitle)
    } else {
      let percentage = Int(progress * 100)
      task.updateTitle(task.title, subtitle: "Processing: \(percentage)%")
    }
  }

  /// Check if transcription should continue
  public var canContinue: Bool {
    return shouldContinue
  }

  /// Complete the current task
  public func completeTask(success: Bool) {
    currentTask?.setTaskCompleted(success: success)
    currentTask = nil
    currentTaskId = nil
    isTranscribingInBackground = false
    shouldContinue = true
  }

  private func handleBackgroundTask(_ task: BGContinuedProcessingTask) {
    currentTask = task
    shouldContinue = true

    // Set up expiration handler
    task.expirationHandler = { [weak self] in
      self?.shouldContinue = false
      self?.isTranscribingInBackground = false
    }

    // The actual transcription will be handled by the Service
    // This just sets up the task management
  }
}
