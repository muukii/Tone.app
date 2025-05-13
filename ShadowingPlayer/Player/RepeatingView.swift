import AppService
import SwiftUI
import SwiftUISupport
import Verge

struct RepeatingView: View {

  private let range: PlayingRange
  
  let controller: PlayerController
  @Namespace var namespace

  @MainActor
  init(
    controller: PlayerController
  ) {
    self.range = controller.playingRange!
    self.controller = controller
  }

  var body: some View {

    VStack {
      ZStack {

        Color.clear

        Group {
          if let currentCue = controller.currentCue {
            makeText("\(currentCue.backed.text)")
              .id(UUID())
              .transition(MyTransition().animation(.bouncy))
            //              .drawingGroup(opaque: false)
          }
        }
      }

      Spacer(minLength: 0)

      PlayerControlPanel(
        controller: controller,
        namespace: namespace,
        onTapPin: {
        },
        onTapDetail: {})
    }

  }

}

private func makeText(_ text: String) -> some View {
  Text(text)
    .font(.system(size: 38, weight: .bold, design: .default))
}

private struct TextEmitting: View {

  @State var text: String = ""

  var body: some View {

    TimelineView(.periodic(from: .now, by: 0.5)) { context in
      VStack {
        Text(context.date.description)
          .id(context.date)
          .transition(MyTransition())
      }
    }
  }

}

private struct MyTransition: Transition {

  nonisolated(unsafe) func body(content: Content, phase: TransitionPhase) -> some View {
        
    content
      .scaleEffect({
        switch phase {
        case .willAppear:
           return .zero
        case .identity:
          return .init(width: 1, height: 1)
        case .didDisappear:        
          return .zero
        }
      }())
      .opacity({
        switch phase {
        case .willAppear:
          return 0
        case .identity:
          return 1
        case .didDisappear:        
          return 0
        }
      }())
      .blur(radius: {
        switch phase {
        case .willAppear:
          return 0
        case .identity:
          return 0
        case .didDisappear:        
          return 40
        }
      }())
      .animatableOffset(y: {
        switch phase {
        case .willAppear:
          return 80
        case .identity:
          return 0
        case .didDisappear:        
          return -400
        }
      }())
      .animation({
        switch phase {
        case .willAppear:
          return .spring
        case .identity:
          return .spring(response: 0.4)
        case .didDisappear:        
          return .spring(response: 5)
        }
      }(),value: phase)
       
  }
}

#Preview {
  TextEmitting()
}
