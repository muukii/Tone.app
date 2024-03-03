import AppService
import SwiftUI
import SwiftUISupport

struct RepeatingView: View {

  private unowned let controller: PlayerController
  private let range: PlayingRange

  @Namespace var namespace

  @MainActor
  init(
    controller: PlayerController
  ) {
    self.controller = controller
    self.range = controller.playingRange!
  }

  var body: some View {

    VStack {
      ZStack {

        Color.clear

        Group {
          if let currentCue = controller.currentCue {
            //            if let before = range.before(currentCue) {
            //              makeText("\(before.backed.text)")
            //                .transition(.opacity)
            //            }
            makeText("\(controller.currentCue?.backed.text ?? "")")
              .id(currentCue)
              .transition(
                .asymmetric(
                  insertion: .modifier(
                    active: StyleModifier(opacity: 0, scale: .zero, blurRadius: 10),
                    identity: StyleModifier.identity
                  )
                  .animation(.spring(.snappy(extraBounce: 0.35))),
                  removal: .modifier(
                    active: StyleModifier(opacity: 0, scale: .init(width: 0.8, height: 0.9), offset: .init(width: 0, height: -400), blurRadius: 5),
                    identity: StyleModifier.identity
                  )
                  .animation(.smooth(duration: 3))
                )

              )
              .drawingGroup(opaque: false)
            //              .transition(.scale)
            //            if let after = range.after(currentCue) {
            //              makeText("\(after.backed.text)")
            //                .transition(.opacity)
            //            }
          }
        }
      }

      Spacer(minLength: 0)

      //      ScrollViewReader(content: { proxy in
      //        ScrollView(.horizontal) {
      //          HStack {
      //            ForEach(range.cues) { cue in
      //              makeChunk(
      //                text: cue.backed.text,
      //                hasMark: false,
      //                identifier: cue.id,
      //                isFocusing: controller.currentCue == cue,
      //                isInRange: true,
      //                onSelect: {
      //                })
      //            }
      //          }
      //        }
      //        .onChange(of: controller.currentCue, initial: true) { _, new in
      //          guard let new else { return }
      //          withAnimation(.bouncy) {
      //            proxy.scrollTo(new.id, anchor: .center)
      //          }
      //        }
      //      })
      PlayerControlPanel(controller: controller, onTapPin: {}, onTapDetail: {})
    }

  }

}

private func makeText(_ text: String) -> some View {
  Text(text)
    .font(.system(size: 38, weight: .bold, design: .default))
}

#Preview {
  makeText("Hello")
}
