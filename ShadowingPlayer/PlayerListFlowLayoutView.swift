import DynamicList
import SwiftUI
import SwiftUISupport
import Verge

struct PlayerListFlowLayoutView: View, PlayerDisplay {

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

    DynamicList<String, DisplayCue>(
      snapshot: .init()&>.modify({ s in
        s.appendSections(["Main"])
        s.appendItems(cues, toSection: "Main")
      }),
      layout: {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = .init(width: 50, height: 50)
        return layout
      },
      scrollDirection: .vertical,
      cellProvider: { context in

        let cue = context.data

        return context.cell { state in
          PlayerListFlowLayoutView.chunk(
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
          .listRowSeparator(.hidden)
          .listRowInsets(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
          .contextMenu {
            Button("Pin") {
              actionHandler(.onPin(cue))
            }
          }
        }
      }
    )
//    .selectionHandler { action in
//      switch action {
//      case .didSelect(let data, _):
//        print(data)
//        break
//      case .didDeselect(_, _):
//        break
//      }
//    }

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
    VStack(spacing: 4) {
      Text(text).font(.system(size: 24, weight: .bold, design: .default))
        .modifier(
          condition: isFocusing == false,
          identity: StyleModifier(scale: .init(width: 1.05, height: 1.05)),
          active: StyleModifier(opacity: 0.2)
        )
        .id(identifier)
        .textSelection(.enabled)

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
        .frame(height: 4)
    }
    .padding(.horizontal, 2)
    ._onButtonGesture(
      pressing: { isPressing in },
      perform: {
        onSelect()
      }
    )
  }
}

private final class ViewModel: StoreDriverType {

  struct State: StateType {

  }

  let store: UIStateStore<State, Never>

  init() {
    self.store = .init(initialState: .init())
  }

}

#if DEBUG

#Preview {
  Group {
    PlayerView<PlayerListFlowLayoutView>(
      playerController: try! .init(item: .social),
      actionHandler: { action in
      }
    )
  }
}

#endif
