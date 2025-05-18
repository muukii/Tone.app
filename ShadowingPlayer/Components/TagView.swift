import SwiftUI

struct TagView: View {

  let tag: String

  var body: some View {
    Text(tag)
      .font(.caption)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.tertiary)
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .inset(by: 1)
            .stroke(.secondary, lineWidth: 2)
        }
      )
      .foregroundStyle(.red)
      .cornerRadius(4)
  }

}

#Preview("Tag") {
  TagView(tag: "SwiftUI")
}
