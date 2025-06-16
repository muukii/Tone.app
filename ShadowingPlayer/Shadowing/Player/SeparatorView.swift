import SwiftUI
import SwiftUISupport
import AppService

struct SeparatorView: View {

  let preferredWidth: CGFloat?
  let identifier: DisplayCue.ID
  let onAction: (PlayerChunkAction) -> Void

  init(
    preferredWidth: CGFloat?,
    identifier: DisplayCue.ID,
    onAction: @escaping (PlayerChunkAction) -> Void
  ) {
    self.preferredWidth = preferredWidth
    self.identifier = identifier
    self.onAction = onAction
  }

  var body: some View {
    // Separator visual representation
    HStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 8)
        .fill(.quinary)
        .frame(height: 30)
    }
    .frame(minWidth: preferredWidth)
    .contextMenu {
      Button(role: .destructive) {
        onAction(.deleteSeparator(cueId: String(describing: identifier)))
      } label: {
        Label("Delete Separator", systemImage: "trash")
      }
    }
  }
}

#Preview("Separator") {
  HStack {
    Spacer()
    SeparatorView(
      preferredWidth: nil,
      identifier: "test-separator",
      onAction: { action in
        print("Action: \(action)")
      }
    )
    Spacer()
  }
  .fixedSize()
}
