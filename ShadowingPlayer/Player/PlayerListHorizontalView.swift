import SwiftUI
import SwiftUISupport
import AppService

struct PlayerListHorizontalView: View, PlayerDisplay {

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
    let playingRange = controller.playingRange
    let isRepeating = controller.isRepeating
    let focusing = controller.currentCue

    ScrollViewReader { proxy in
      ScrollView(.vertical) {
      ForEachChunk(scrollViewProxy: proxy, cues: cues, controller: controller) {
            cue in
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


      }
      .safeAreaPadding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
//      .onChange(
//        of: focusing,
//        { oldValue, cue in
//
//          guard let cue else { return }
//
//          withAnimation(.bouncy) {
//            proxy.scrollTo(cue.id, anchor: .center)
//          }
//
//        }
//      )

    }

  }

}

// to avoid re-rendering ForEach by updating parent's update
private struct ForEachChunk: View {

  let scrollViewProxy: ScrollViewProxy
  let cues: [DisplayCue]
  let controller: PlayerController
  let onSelect: (DisplayCue) -> Void

  var body: some View {

    FlowLayout(alignment: .leading) {
      ForEach(cues) { cue in
        Chunk(
          controller: controller,
          cue: cue,
          onSelect: {
            onSelect(cue)
          }
        )
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
      }
    }

  }

}

private struct Chunk: View {

  let controller: PlayerController
  let cue: DisplayCue
  let onSelect: () -> Void

  var body: some View {

    let playingRange = controller.playingRange

    VStack(spacing: 4) {
      Text(cue.backed.text).font(.system(size: 24, weight: .bold, design: .default))
        .modifier(
          condition: controller.currentCue != cue,
          identity: StyleModifier(scale: .init(width: 1.05, height: 1.05)),
          active: StyleModifier(opacity: 0.2)
        )
        .id(cue.id)
        .textSelection(.enabled)

      // Indicator
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          { () -> Color in
            if let playingRange, playingRange.contains(cue) {
              return Color.accentColor
            }

            if controller.currentCue == cue {
              return Color.primary
            }

            return Color.primary.opacity(0.3)

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

//private struct Body: View {
//
//
//
//  init(controller: PlayerController) {
//
//  }
//
//  var body: some View {
//    FlowLayout(alignment: .leading) {
//      ForEach(cues) { cue in
//        Self.chunk(
//          text: cue.backed.text,
//          identifier: cue.id,
//          isFocusing: false,
//          isInRange: playingRange?.contains(cue) ?? false,
//          onSelect: {
//            if isRepeating {
//
//              if var currentRange = playingRange {
//
//                currentRange.select(cue: cue)
//
//                controller.setRepeat(range: currentRange)
//
//              } else {
//
//              }
//            } else {
//              controller.move(to: cue)
//            }
//          }
//        )
//        .listRowSeparator(.hidden)
//        .listRowInsets(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
//        .contextMenu {
//          Button("Pin") {
//            actionHandler(.onPin(cue))
//
//          }
//        }
//      }
//    }
//  }
//}

private struct FlowLayout: Layout {
  var alignment: Alignment = .center
  var spacing: CGFloat?

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let result = FlowResult(
      in: proposal.replacingUnspecifiedDimensions().width,
      subviews: subviews,
      alignment: alignment,
      spacing: spacing
    )
    return result.bounds
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) {
    let result = FlowResult(
      in: proposal.replacingUnspecifiedDimensions().width,
      subviews: subviews,
      alignment: alignment,
      spacing: spacing
    )
    for row in result.rows {
      let rowXOffset = (bounds.width - row.frame.width) * alignment.horizontal.percent
      for index in row.range {
        let xPos =
          rowXOffset + row.frame.minX + row.xOffsets[index - row.range.lowerBound] + bounds.minX
        let rowYAlignment =
          (row.frame.height - subviews[index].sizeThatFits(.unspecified).height)
          * alignment.vertical.percent
        let yPos = row.frame.minY + rowYAlignment + bounds.minY
        subviews[index].place(
          at: CGPoint(x: xPos, y: yPos),
          anchor: .topLeading,
          proposal: .unspecified
        )
      }
    }
  }

  struct FlowResult {
    var bounds = CGSize.zero
    var rows = [Row]()

    struct Row {
      var range: Range<Int>
      var xOffsets: [Double]
      var frame: CGRect
    }

    init(in maxPossibleWidth: Double, subviews: Subviews, alignment: Alignment, spacing: CGFloat?) {
      var itemsInRow = 0
      var remainingWidth = maxPossibleWidth.isFinite ? maxPossibleWidth : .greatestFiniteMagnitude
      var rowMinY = 0.0
      var rowHeight = 0.0
      var xOffsets: [Double] = []
      for (index, subview) in zip(subviews.indices, subviews) {
        let idealSize = subview.sizeThatFits(.unspecified)
        if index != 0 && widthInRow(index: index, idealWidth: idealSize.width) > remainingWidth {
          finalizeRow(index: max(index - 1, 0), idealSize: idealSize)
        }
        addToRow(index: index, idealSize: idealSize)

        if index == subviews.count - 1 {
          finalizeRow(index: index, idealSize: idealSize)
        }
      }

      func spacingBefore(index: Int) -> Double {
        guard itemsInRow > 0 else { return 0 }
        return spacing
          ?? subviews[index - 1].spacing.distance(to: subviews[index].spacing, along: .horizontal)
      }

      func widthInRow(index: Int, idealWidth: Double) -> Double {
        idealWidth + spacingBefore(index: index)
      }

      func addToRow(index: Int, idealSize: CGSize) {
        let width = widthInRow(index: index, idealWidth: idealSize.width)

        xOffsets.append(maxPossibleWidth - remainingWidth + spacingBefore(index: index))
        remainingWidth -= width
        rowHeight = max(rowHeight, idealSize.height)
        itemsInRow += 1
      }

      func finalizeRow(index: Int, idealSize: CGSize) {
        let rowWidth = maxPossibleWidth - remainingWidth
        rows.append(
          Row(
            range: index - max(itemsInRow - 1, 0)..<index + 1,
            xOffsets: xOffsets,
            frame: CGRect(x: 0, y: rowMinY, width: rowWidth, height: rowHeight)
          )
        )
        bounds.width = max(bounds.width, rowWidth)
        let ySpacing = spacing ?? ViewSpacing().distance(to: ViewSpacing(), along: .vertical)
        bounds.height += rowHeight + (rows.count > 1 ? ySpacing : 0)
        rowMinY += rowHeight + ySpacing
        itemsInRow = 0
        rowHeight = 0
        xOffsets.removeAll()
        remainingWidth = maxPossibleWidth
      }
    }
  }
}

extension HorizontalAlignment {
  fileprivate var percent: Double {
    switch self {
    case .leading: return 0
    case .trailing: return 1
    default: return 0.5
    }
  }
}

extension VerticalAlignment {
  fileprivate var percent: Double {
    switch self {
    case .top: return 0
    case .bottom: return 1
    default: return 0.5
    }
  }
}

#if DEBUG

#Preview {
  Group {
    PlayerView<PlayerListHorizontalView>(
      playerController: { try! .init(item: .social) },
      actionHandler: { action in
      }
    )
  }
}

#endif
