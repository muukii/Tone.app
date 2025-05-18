import SwiftUI
import SwiftUISupport

struct ChunkView: View {
  let text: String
  let hasMark: Bool
  let identifier: AnyHashable
  let isFocusing: Bool
  let isInRange: Bool
  let onSelect: () -> Void
  let onAction: (PlayerChunkAction) -> Void

  init(
    text: String,
    hasMark: Bool,
    identifier: some Hashable,
    isFocusing: Bool,
    isInRange: Bool,
    onSelect: @escaping () -> Void,
    onAction: @escaping (PlayerChunkAction) -> Void = { _ in }
  ) {
    self.text = text
    self.hasMark = hasMark
    self.identifier = AnyHashable(identifier)
    self.isFocusing = isFocusing
    self.isInRange = isInRange
    self.onSelect = onSelect
    self.onAction = onAction
  }

  var body: some View {
    VStack(spacing: 4) {
      HStack {
        if hasMark {
          VStack {
            Circle()
              .frame(width: 6, height: 6)
              .foregroundStyle(.secondary)
            Spacer()
          }
        }

        Text(text).font(.system(size: 24, weight: .bold, design: .default))
          .modifier(
            condition: isFocusing == false,
            identity: StyleModifier(scale: .init(width: 1.1, height: 1.1)),
            active: StyleModifier(opacity: 0.2)
          )
          .id(identifier)
          
      }

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

            return Color.secondary
          }()
        )
        .frame(height: 4)
        .padding(.horizontal, isFocusing ? 0 : 2)
    }
    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 8, style: .continuous))
    .contextMenu {
      Button {
        onAction(.copy(text: text))
      } label: {
        Label("Copy", systemImage: "doc.on.doc")
      }
      
      Divider()
      
      if hasMark {
        Button {
          onAction(.removeMark(identifier: String(describing: identifier)))
        } label: {
          Label("Remove Mark", systemImage: "bookmark.slash")
        }
      } else {
        Button {
          onAction(.addMark(identifier: String(describing: identifier)))
        } label: {
          Label("Add Mark", systemImage: "bookmark")
        }
      }

      Divider()

      Button {
        onAction(.addToFlashcard(identifier: String(describing: identifier)))
      } label: {
        Label("Add to Flashcard", systemImage: "rectangle.stack.badge.plus")
      }
    }
    .animation(.bouncy, value: isFocusing)
    .transaction(
      value: identifier,
      { t in
        // prevent animation while reusing
        t.disablesAnimations = true
      }
    )
    .padding(.horizontal, 2)
    ._onButtonGesture(
      pressing: { isPressing in },
      perform: {
        onSelect()
      }
    )
  }
}

#Preview("Cell") {
  HStack {
    Spacer()
    ChunkView(
      text: "Hello",
      hasMark: true,
      identifier: "foo",
      isFocusing: false,
      isInRange: false,
      onSelect: {
        
      },
      onAction: { action in
        print("Action: \(action)")
      }
    )
    Spacer()
  }
  .fixedSize()
}
