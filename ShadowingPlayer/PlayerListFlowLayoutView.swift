import DynamicList
import SwiftUI
import SwiftUISupport
import Verge

struct PlayerListFlowLayoutView: View, PlayerDisplay {

  init(
    cues: [DisplayCue],
    focusing: DisplayCue?,
    playingRange: PlayerController.PlayingRange?,
    isRepeating: Bool,
    actionHandler: @escaping (PlayerDisplayAction) -> Void
  ) {
    self.cues = cues
    self.focusing = focusing
    self.playingRange = playingRange
    self.isRepeating = isRepeating
    self.actionHandler = actionHandler
  }

  let cues: [DisplayCue]
  let focusing: DisplayCue?
  let playingRange: PlayerController.PlayingRange?
  let isRepeating: Bool
  let actionHandler: (PlayerDisplayAction) -> Void

  var body: some View {

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

                  actionHandler(.setRepeat(range: currentRange))

                } else {

                }
              } else {
                actionHandler(.move(to: cue))
              }
            }
          )
          .listRowSeparator(.hidden)
          .listRowInsets(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
          .contextMenu {
            Button("Pin") {
              actionHandler(.pin(cue))
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
    VStack {
      Text(text).font(.system(size: 24, weight: .bold, design: .default))
        .modifier(
          condition: isFocusing == false,
          identity: StyleModifier(scale: .init(width: 1.1, height: 1.1)),
          active: StyleModifier(opacity: 0.2)
        )
        .padding(6)
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
        .frame(height: 16)
    }
    .padding(8)
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
