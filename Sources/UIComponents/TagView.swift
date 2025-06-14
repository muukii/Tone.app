import SwiftUI

public struct TagView: View {

  let tag: String

  public init(tag: String) {
    self.tag = tag
  }

  public var body: some View {
    Text(tag)
      .font(.subheadline)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.tertiary)
        }
      )
      .cornerRadius(4)
  }

}

#Preview("Tag") {
  VStack {
    TagView(tag: "SwiftUI")
      .foregroundColor(.blue)
  }
}
