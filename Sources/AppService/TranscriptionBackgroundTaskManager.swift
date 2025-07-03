import BackgroundTasks
import Foundation
import StateGraph

#if swift(>=6.2)
@available(iOS 26.0, *)
public final class TranscriptionBackgroundTaskManager: Sendable {

  public static let taskIdentifier = "app.muukii.tone.transcription"
 
  @MainActor
  private var isRegistered: Bool = false
  
  @GraphStored
  private var scheduledItems: [String : (BGContinuedProcessingTask) -> Void] = [:]

  public init() {}
    
  /// Register the background task handler
  @MainActor
  public func register() {
    guard !isRegistered else { return }
    isRegistered = true

 
  }

  /// Submit a background task for transcription
  public func submitTask(
    itemTitle: String,
    itemId: String,
    onStart: @escaping @Sendable (BGContinuedProcessingTask) -> Void
  ) throws {
    
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: itemId,
      using: nil,
      launchHandler: { @Sendable task in
        guard let task = task as? BGContinuedProcessingTask else {
          task.setTaskCompleted(success: false)
          return
        }
        onStart(task)
      }
    )
        
    let request = BGContinuedProcessingTaskRequest(
      identifier: itemId,
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
            
  }

}

#endif

