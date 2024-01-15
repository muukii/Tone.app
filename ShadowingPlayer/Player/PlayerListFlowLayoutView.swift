import DynamicList
import SwiftUI
import SwiftUISupport
import Verge
import AppService
import MondrianLayout

private enum CellIsFocusing: CustomStateKey {
  typealias Value = Bool

  static var defaultValue: Bool { false }
}

private enum CellPlayingRange: CustomStateKey {
  typealias Value = PlayingRange?

  static var defaultValue: PlayingRange? {
    nil
  }
}


extension CellState {

  var isFocusing: Bool {
    get { self[CellIsFocusing.self] }
    set { self[CellIsFocusing.self] = newValue }
  }

  var playingRange: PlayingRange? {
    get { self[CellPlayingRange.self] }
    set { self[CellPlayingRange.self] = newValue }
  }

}

@MainActor
struct PlayerListFlowLayoutView: View, PlayerDisplay {

  private unowned let controller: PlayerController
  private let actionHandler: @MainActor (PlayerAction) -> Void

  init(
    controller: PlayerController,
    actionHandler: @escaping @MainActor (PlayerAction) -> Void
  ) {
    self.controller = controller
    self.actionHandler = actionHandler
  }

  private func makeCellState() -> [DisplayCue : CellState] {
    var cellStates: [DisplayCue : CellState] = [:]
    let focusing = controller.currentCue
    if let focusing {
      cellStates[focusing, default: .empty].isFocusing = true
    }

    if let playingRange = controller.playingRange {
      for cue in controller.cues {
        cellStates[cue, default: .empty].playingRange = playingRange
      }
    }

    return cellStates
  }

  var body: some View {

    let cues = controller.cues

    DynamicList<String, DisplayCue>(
      snapshot: .init()&>.modify({ s in
        s.appendSections(["Main"])
        s.appendItems(cues, toSection: "Main")
      }),
      cellStates: makeCellState(),
      layout: {
        let layout = AlignedCollectionViewFlowLayout(horizontalAlignment: .leading)
        layout.estimatedItemSize = .init(width: 50, height: 50)
        layout.sectionInset = .init(top: 0, left: 16, bottom: 0, right: 16)
        return layout

//        let layout = UICollectionViewFlowLayout()
//        layout.estimatedItemSize = .init(width: 50, height: 50)
//        return layout
      },
      scrollDirection: .vertical,
      contentInsetAdjustmentBehavior: .always,
      cellProvider: { [weak controller] context in

        let cue = context.data

//        return context.cell { cell, state, cellState in
//          return CueCellContentConfiguration(
//            text: cue.backed.text,
//            isFocusing: cellState.isFocusing,
//            isInRange: cellState.playingRange?.contains(cue) ?? false,
//            accentColor: .systemMint
//          )
//        }

        return context.cell { state, customState in
          makeChunk(
            text: cue.backed.text,
            identifier: cue.id,
            isFocusing: customState.isFocusing,
            isInRange: customState.playingRange?.contains(cue) ?? false,
            onSelect: {
              guard let controller else { return }
              if controller.isRepeating {

                if var currentRange = customState.playingRange {

                  currentRange.select(cue: cue)

                  controller.setRepeat(range: currentRange)

                } else {

                }
              } else {
                controller.move(to: cue)
              }
            }
          )
        }
        
      }
    )
    .scrolling(to: controller.currentCue)

  }

}

nonisolated func makeChunk(
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
        identity: StyleModifier(scale: .init(width: 1.1, height: 1.1)),
        active: StyleModifier(opacity: 0.2)
      )
      .id(identifier)
      .textSelection(.enabled)

    // Indicator
    RoundedRectangle(cornerRadius: 8, style: .continuous)
      .fill(
        { () -> Color in
          if isInRange {
            return Color.accentColor
          }

          if isFocusing {
            return Color.primary
          }

          return Color.primary.opacity(0.3)

        }()
      )
      .frame(height: 4)
      .padding(.horizontal, isFocusing ? 0 : 2)
  }
  .animation(.bouncy, value: isFocusing)
  .transaction(value: identifier, { t in
    // prevent animation while reusing
    t.disablesAnimations = true
  })
  .padding(.horizontal, 2)
  ._onButtonGesture(
    pressing: { isPressing in },
    perform: {
      onSelect()
    }
  )
}

private final class ViewModel: StoreDriverType {

  struct State: StateType {

  }

  let store: UIStateStore<State, Never>

  init() {
    self.store = .init(initialState: .init())
  }

}

private final class CueCellContentView: UIView, UIContentView {

  private let textLabel: UILabel = .init()
  private let underlineView: UIView = .init()

  var configuration: UIContentConfiguration {
    didSet {
      update(with: configuration as! CueCellContentConfiguration)
    }
  }

  init(configuration: CueCellContentConfiguration) {
    self.configuration = configuration
    super.init(frame: .zero)

    underlineView.backgroundColor = .white

    Mondrian.buildSubviews(on: self) {
      VStackBlock {
        textLabel

        underlineView
          .viewBlock
          .height(2)
      }
    }

    update(with: configuration)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func update(with configuration: CueCellContentConfiguration) {

    textLabel.text = configuration.text

  }

}

private struct CueCellContentConfiguration: UIContentConfiguration {

  let text: String
  let isFocusing: Bool
  let isInRange: Bool

  let accentColor: UIColor

  func makeContentView() -> UIView & UIContentView {
    CueCellContentView(configuration: self)
  }
  
  func updated(for state: UIConfigurationState) -> CueCellContentConfiguration {
    return self
  }
}

#if DEBUG

#Preview {
  Group {
    PlayerView<PlayerListFlowLayoutView>(
      playerController: { try! .init(item: .social) },
      actionHandler: { action in
      }
    )
  }
}

#endif
