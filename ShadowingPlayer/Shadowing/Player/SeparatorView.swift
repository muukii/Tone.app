import SwiftUI
import SwiftUISupport

struct SeparatorView: View {
  let identifier: AnyHashable
  let isFocusing: Bool
  let isInRange: Bool
  let onSelect: () -> Void
  
  init(
    identifier: some Hashable,
    isFocusing: Bool,
    isInRange: Bool,
    onSelect: @escaping () -> Void
  ) {
    self.identifier = AnyHashable(identifier)
    self.isFocusing = isFocusing
    self.isInRange = isInRange
    self.onSelect = onSelect
  }
  
  var body: some View {
    VStack(spacing: 4) {
      // Separator visual representation
      HStack(spacing: 8) {
        Circle()
          .frame(width: 4, height: 4)
          .foregroundStyle(.secondary)
        Circle()
          .frame(width: 4, height: 4)
          .foregroundStyle(.secondary)
        Circle()
          .frame(width: 4, height: 4)
          .foregroundStyle(.secondary)
      }
      .modifier(
        condition: isFocusing == false,
        identity: StyleModifier(scale: .init(width: 1.1, height: 1.1)),
        active: StyleModifier(opacity: 0.2)
      )
      .id(identifier)
      
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
            
            return Color.clear
          }()
        )
        .frame(height: 2)
        .padding(.horizontal, isFocusing ? 0 : 2)
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

#Preview("Separator") {
  HStack {
    Spacer()
    SeparatorView(
      identifier: "separator",
      isFocusing: false,
      isInRange: false,
      onSelect: {}
    )
    Spacer()
  }
  .fixedSize()
}