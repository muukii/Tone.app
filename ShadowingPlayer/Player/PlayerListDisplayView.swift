import SwiftUI
import SwiftUISupport
import AppService

struct PlayerListDisplayView: View, PlayerDisplay {

  private let controller: PlayerController
  private let actionHandler: @MainActor (PlayerAction) -> Void

  init(
    controller: PlayerController,
    actionHandler: @escaping @MainActor (PlayerAction) -> Void
  ) {
    self.controller = controller
    self.actionHandler = actionHandler
  }

  var body: some View {

    let cues = controller.cues
    let focusing = controller.currentCue
    let playingRange = controller.playingRange
    let isRepeating = controller.isRepeating

    ScrollViewReader { proxy in
      List {
        ForEach(cues) { cue in
          Self.chunk(
            text: cue.backed.text,
            identifier: cue.id,
            isFocusing: cue == focusing,
            isInRange: playingRange?.contains(cue) ?? false,
            onSelect: {
              if isRepeating {

                if var currentRange = playingRange {

                  currentRange.select(cue: cue)

                  controller.setRepeat(range: currentRange)

                } else {

                }
              } else {

                controller.move(to: cue)
              }
            }
          )
          .animation(.bouncy, value: focusing)
          .listRowSeparator(.hidden)
          .listRowInsets(.init(top: 10, leading: 20, bottom: 10, trailing: 20))     
        }
      }
      .listStyle(.plain)
      .onChange(
        of: focusing,
        { oldValue, cue in

          guard let cue else { return }

          withAnimation(.bouncy) {
            proxy.scrollTo(cue.id, anchor: .center)
          }

        }
      )
    }

  }

  private nonisolated static func chunk(
    text: String,
    identifier: some Hashable,
    isFocusing: Bool,
    isInRange: Bool,
    onSelect: @escaping () -> Void
  )
  -> some View
  {
    HStack {
      Text(text).font(.system(size: 24, weight: .bold, design: .default))
        .modifier(
          condition: isFocusing == false,
          identity: StyleModifier(scale: .init(width: 1.1, height: 1.1)),
          active: StyleModifier(opacity: 0.2)
        )
        .padding(6)
        .id(identifier)
        .textSelection(.enabled)

      Spacer()

      // Indicator
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          { () -> Color in
            if isInRange {
              return Color.blue
            } else if isFocusing {
              return Color.primary
            } else {
              return Color.primary.opacity(0.3)
            }
          }()
        )
        .frame(width: 40)
        ._onButtonGesture(
          pressing: { isPressing in },
          perform: {
            onSelect()
          }
        )
    }
  }
}

#if DEBUG

#Preview {
  Group {
    PlayerView<PlayerListDisplayView>(
      playerController: { try! .init(item: .overwhelmed) },
      actionHandler: { action in
      }
    )
  }
}

#endif
