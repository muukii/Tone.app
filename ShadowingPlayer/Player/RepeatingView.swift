import AppService
import SwiftUI

struct RepeatingView: View {

  private unowned let controller: PlayerController
  private let range: PlayingRange

  @MainActor
  init(
    controller: PlayerController
  ) {
    self.controller = controller
    self.range = controller.playingRange!
  }

  var body: some View {

    VStack {
      ScrollViewReader(content: { proxy in
        ScrollView(.horizontal) {
          HStack {
            ForEach(range.cues) { cue in
              makeChunk(text: cue.backed.text, identifier: cue.id, isFocusing: controller.currentCue == cue, isInRange: true, onSelect: {})
            }
          }
        }
        .onChange(of: controller.currentCue, initial: true) { _, new in
          guard let new else { return }
          withAnimation(.bouncy) {
            proxy.scrollTo(new.id, anchor: .center)
          }
        }
      })
      PlayerControlPanel(controller: controller, onTapPin: {}, onTapDetail: {})
    }

  }

}
