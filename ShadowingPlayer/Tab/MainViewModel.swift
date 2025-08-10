import StateGraph
import AppService

final class MainViewModel {

  @GraphStored
  var currentController: PlayerController?

  init() {
    self.currentController = nil
  }

  @MainActor
  func setPlayerController(for item: ItemEntity) throws {

    if let controller = currentController {
      if controller.source == .entity(item) {
        return
      }
    }
    
    let newController = try PlayerController(item: item)

    currentController = newController
  }

  @MainActor
  func discardPlayerController() {
        
    AudioSessionManager.shared.resetToDefaultState()

    currentController?.pause()
    currentController = nil

  }

}
