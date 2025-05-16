import SwiftUI

public struct PlaceholderTextEditor: View {

  let placeholder: String

  @Binding var text: String

  public init(
    placeholder: String,
    text: Binding<String>
  ) {
    self.placeholder = placeholder
    self._text = text
  }

  public var body: some View {
    TextEditor(text: $text)
      .overlay(
        TextEditor(text: .constant(placeholder))
          .opacity(0.3)
          .opacity(text.isEmpty ? 1 : 0)
          .allowsHitTesting(false)
          .accessibilityHidden(true),
        alignment: .topLeading
      )
  }

}
