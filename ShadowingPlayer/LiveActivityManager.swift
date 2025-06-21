import Foundation
import ActivityKit
import ActivityContent
import Combine
import AppService
import StateGraph
import ConcurrencyTaskManager

@available(iOS 16.1, *)
@MainActor
public final class LiveActivityManager {
  
  private enum TaskKey: TaskKeyType {
    
  }
  
  public static let shared = LiveActivityManager()
  
  private var currentActivityID: String?
  private weak var currentPlayerController: PlayerController?
  private var cancellables = Set<AnyCancellable>()
  
  private let taskManager = TaskManagerActor()
  
  private init() {}    
  
  public func startActivity(
    itemId: String,
    title: String,
    artist: String? = nil,
    isPlaying: Bool
  ) {
    
    Task {
      await taskManager.task(key: .init(TaskKey.self), mode: .waitInCurrent) { 
        // 既存のアクティビティを終了
        if let activityID = self.currentActivityID {
          for activity in Activity<PlayerActivityAttributes>.activities {
            if activity.id == activityID {
              await activity.end(nil, dismissalPolicy: .immediate)
              break
            }
          }
        }
        
        // アクティビティが有効か確認
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
          throw LiveActivityError.activitiesNotEnabled
        }
        
        let attributes = PlayerActivityAttributes(itemId: itemId)
        let contentState = PlayerActivityAttributes.ContentState(
          title: title,
          artist: artist,
          isPlaying: isPlaying
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        do {
          let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
          )
          self.currentActivityID = activity.id
        } catch {
          throw LiveActivityError.failedToStart(error)
        }
      }
      
    }
  }
  
  public func updateActivity(
    title: String,
    artist: String? = nil,
    isPlaying: Bool
  ) {
    
    Task {
      await taskManager.task(key: .init(TaskKey.self), mode: .waitInCurrent) { 
        
        guard let activityID = self.currentActivityID else { return }
        
        let contentState = PlayerActivityAttributes.ContentState(
          title: title,
          artist: artist,
          isPlaying: isPlaying
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        for activity in Activity<PlayerActivityAttributes>.activities {
          if activity.id == activityID {
            await activity.update(content)
            break
          }
        }
      }
    }
    
  
  }
  
  public func endActivity() {
    
    Task {
      await taskManager.task(key: .init(TaskKey.self), mode: .waitInCurrent) {
        
        guard let activityID = self.currentActivityID else { return }
        
        for activity in Activity<PlayerActivityAttributes>.activities {
          if activity.id == activityID {
            await activity.end(nil, dismissalPolicy: .immediate)
            break
          }
        }
        
        self.currentActivityID = nil
      }
    }
       
  }
  
  public var isActivityActive: Bool {
    currentActivityID != nil
  }
  
}

public enum LiveActivityError: LocalizedError {
  case activitiesNotEnabled
  case failedToStart(Error)
  
  public var errorDescription: String? {
    switch self {
    case .activitiesNotEnabled:
      return "Live Activities are not enabled"
    case .failedToStart(let error):
      return "Failed to start Live Activity: \(error.localizedDescription)"
    }
  }
}
