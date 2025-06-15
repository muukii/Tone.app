import SwiftUI
import SwiftUISupport

struct SeparatorView: View {

  let preferredWidth: CGFloat?

  init(preferredWidth: CGFloat?) {
    self.preferredWidth = preferredWidth
  }

  var body: some View {
    // Separator visual representation
    HStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 8)
        .fill(.quinary)
        .frame(height: 30)
    }
    .frame(minWidth: preferredWidth)

  }
}

#Preview("Separator") {
  HStack {
    Spacer()
    SeparatorView(preferredWidth: nil)
    Spacer()
  }
  .fixedSize()
}
