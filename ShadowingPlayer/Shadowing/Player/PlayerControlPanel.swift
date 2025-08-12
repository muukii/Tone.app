import AppService
import SwiftUI
import UIComponents

struct PlayerControlPanel: View {

  enum Action {
    case onTapPin
    case onTapDetail
    case onStartRecord
    case onStopRecording
  }

  let controller: PlayerController
  private let onAction: @MainActor (Action) -> Void

  let namespace: Namespace.ID

  init(
    controller: PlayerController,
    namespace: Namespace.ID,
    onAction: @escaping @MainActor (Action) -> Void
  ) {
    self.controller = controller
    self.namespace = namespace
    self.onAction = onAction
  }

  private static func fractionLabel(fraction: CGFloat) -> String {
    if fraction < 1 {
      var text = String.init(format: "%0.2f", fraction)
      text.removeFirst()
      return text
    } else {
      return .init(format: "%.1f", fraction)
    }
  }

  var body: some View {
    PlayerControlPanelContent(
      isPlaying: controller.isPlaying,
      isRepeating: controller.isRepeating,
      isRecording: controller.isRecording,
      canRecord: controller.canRecord,
      rate: controller.$rate.binding,
      namespace: namespace,
      onAction: { action in
        handleAction(action)
      }
    )
  }

  private func handleAction(_ action: PlayerControlPanelContent.Action) {
    switch action {
    case .togglePlaying:
      togglePlaying()
    case .toggleRepeat:
      if controller.isRepeating {
        controller.setRepeat(range: nil)
      } else {
        if let currentCue = controller.currentCue {
          var range = controller.makeRepeatingRange()
          range.select(cue: currentCue)
          controller.setRepeat(range: range)
        }
      }
    case .pin:
      onAction(.onTapPin)
    case .detail:
      onAction(.onTapDetail)
    case .startRecord:
      onAction(.onStartRecord)
    case .stopRecording:
      onAction(.onStopRecording)
    case .setRate(let newRate):
      controller.rate = newRate
    case .resetRate:
      controller.rate = 1
    }
  }

  @MainActor
  private func togglePlaying() {
    if controller.isPlaying {
      controller.pause()
    } else {
      controller.play()
    }
  }

}
