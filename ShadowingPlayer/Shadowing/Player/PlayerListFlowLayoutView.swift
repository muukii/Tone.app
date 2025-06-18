import Algorithms
import AppService
import DynamicList
import MondrianLayout
import SwiftUI
import SwiftUISupport
import SwiftUISupportLayout
import UIKit

private enum CellIsFocusing: CustomStateKey {
  typealias Value = Bool

  static var defaultValue: Bool { false }
}

private enum CellHasMark: CustomStateKey {
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

  var hasMark: Bool {
    get { self[CellHasMark.self] }
    set { self[CellHasMark.self] = newValue }
  }

  var isFocusing: Bool {
    get { self[CellIsFocusing.self] }
    set { self[CellIsFocusing.self] = newValue }
  }

  var playingRange: PlayingRange? {
    get { self[CellPlayingRange.self] }
    set { self[CellPlayingRange.self] = newValue }
  }

}

enum PlayerChunkAction {
  case copy(text: String)
  case addMark(identifier: String)
  case removeMark(identifier: String)
  case addToFlashcard(identifier: String)
  case insertSeparatorBefore(cueId: String)
  case deleteSeparator(cueId: String)
}

@MainActor
struct PlayerListFlowLayoutView: View, PlayerDisplay {

  unowned let controller: PlayerController
  private let actionHandler: @MainActor (PlayerAction) async -> Void

  @State var isFollowing: Bool = true

  private let pins: [PinEntity]

  private let snapshot: NSDiffableDataSourceSnapshot<String, DisplayCue>

  init(
    controller: PlayerController,
    pins: [PinEntity],
    actionHandler: @escaping @MainActor (PlayerAction) async -> Void
  ) {
    self.controller = controller
    self.pins = pins
    self.actionHandler = actionHandler

    self.snapshot = NSDiffableDataSourceSnapshot<String, DisplayCue>.init()&>.modify({ s in

      let chunks = controller.cues.chunked(by: {
        // Don't chunk together if there's a time gap > 0.08s OR if the next segment is a separator
        let hasTimeGap = ($1.backed.startTime - $0.backed.endTime > 0.08)
        let nextIsSeparator = $1.backed.kind == .separator
        return !hasTimeGap && !nextIsSeparator
      })

      for (index, chunk) in chunks.enumerated() {
        s.appendSections(["\(index)"])
        s.appendItems(Array(chunk), toSection: "\(index)")
      }
    })
  }

  private func makeCellState(currentCue: DisplayCue?) -> [DisplayCue: CellState] {

    var cellStates: [DisplayCue: CellState] = [:]

    let focusing = currentCue

    if let focusing {
      cellStates[focusing, default: .empty].isFocusing = true
    }

    if let playingRange = controller.playingRange {
      for cue in controller.cues {
        cellStates[cue, default: .empty].playingRange = playingRange
      }
    }

    let pins = Set(pins.map(\.startCueRawIdentifier))

    for cue in controller.cues {

      if pins.contains(cue.id) {
        cellStates[cue, default: .empty].hasMark = true
      }

    }

    return cellStates
  }

  var body: some View {
    
    let currentCue = controller.currentCue

    ZStack {
      DynamicList<String, DisplayCue>(
        snapshot: snapshot,
        cellStates: makeCellState(currentCue: currentCue),
        layout: {
          let layout = AlignedCollectionViewFlowLayout(horizontalAlignment: .leading)
          layout.estimatedItemSize = .init(width: 50, height: 50)
          layout.sectionInset = .init(top: 20, left: 16, bottom: 20, right: 16)
          return layout

        },
        scrollDirection: .vertical,
        contentInsetAdjustmentBehavior: .always,
        cellProvider: { context in

          let cue = context.data

          if cue.backed.kind == .separator {
            return context.cell { cellState, customState in
              SeparatorView(
                preferredWidth: context.collectionView.bounds.width - 32,
                identifier: cue.id,
                onAction: { action in
                  handleAction(action, cue: cue)
                }
              )
            }
          } else {
            return context.cell { cellState, customState in
              ChunkView(
                text: cue.backed.text,
                hasMark: customState.hasMark,
                identifier: cue.id,
                isFocusing: customState.isFocusing,
                isInRange: customState.playingRange?.contains(cue) ?? false,
                onSelect: {
                  if controller.isRepeating {
                    if var currentRange = customState.playingRange {
                      currentRange.select(cue: cue)
                      controller.setRepeat(range: currentRange)
                    }
                  } else {
                    controller.move(to: cue)
                  }
                },
                onAction: { action in
                  handleAction(action, cue: cue)
                }
              )
            }
          }

        }
      )
      .scrollHandler { scrollView, action in
        switch action {
        case .didScroll:
          if scrollView.isTracking {
            Task {
              isFollowing = false
            }
          }
        }
      }
      .scrolling(
        to: currentCue.map {
          .init(
            item: $0,
            skipCondition: { scrollView in
              isFollowing == false || scrollView.isDecelerating || scrollView.isTracking
            },
            animated: true
          )
        }
      )

      Button {
        isFollowing = true
      } label: {
        Image(systemName: "arrow.up.backward.circle.fill")
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.roundedRectangle)
      .opacity(isFollowing ? 0 : 1)
      .relative(horizontalAlignment: .trailing, verticalAlignment: .bottom)
      .padding(20)

    }
  }

  private func handleAction(_ action: PlayerChunkAction, cue: DisplayCue) {
    switch action {
    case .copy(let text):
      UIPasteboard.general.string = text
    case .addMark(let identifier):
      break
    case .removeMark(let identifier):
      break
    case .addToFlashcard(let identifier):
      break
    case .insertSeparatorBefore(let cueId):
      Task {
        await actionHandler(.onInsertSeparator(beforeCueId: cueId))
      }
    case .deleteSeparator(let cueId):
      Task {
        await actionHandler(.onDeleteSeparator(cueId: cueId))
      }
    }
  }

}

#if DEBUG

  #Preview("FollowButton") {
    Button {

    } label: {
      Image(systemName: "arrow.up.backward.circle.fill")
    }
    .buttonStyle(.bordered)
    .buttonBorderShape(.roundedRectangle)
    .tint(.purple)
  }

#endif
