import SwiftUI

public struct MarqueeText: View {
  
  let text: String
  let spacing: CGFloat

  @State private var textWidth: CGFloat = 0
  @State private var containerWidth: CGFloat = 0
  @State private var offset: CGFloat = 0

  private var shouldScroll: Bool {
    textWidth > containerWidth
  }

  private var animationDuration: Double {
    // Calculate duration based on text length (approximately 30 points per second)
    let totalDistance = textWidth + spacing
    return Double(totalDistance) / 30.0
  }

  public init(_ text: String, spacing: CGFloat = 50) {
    self.text = text
    self.spacing = spacing
  }

  public var body: some View {
    GeometryReader { geometry in
      HStack(spacing: spacing) {
        Text(text)
          .fixedSize()
          .background(
            GeometryReader { textGeometry in
              Color.clear
                .onAppear {
                  textWidth = textGeometry.size.width
                  containerWidth = geometry.size.width
                }
            }
          )

        if shouldScroll {
          Text(text)
            .fixedSize()
            .padding(.horizontal, 25)
        }
      }
      .offset(x: offset)
      .onAppear {
        if shouldScroll {
          startAnimation()
        }
      }
      .onChange(of: shouldScroll) { _, newValue in
        if newValue {
          startAnimation()
        } else {
          offset = 0
        }
      }
    }
    .mask {
      HStack(spacing: 0) {
        // 左側のグラデーション
        LinearGradient(
          gradient: Gradient(colors: [.clear, .black]),
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: 8)

        // 中央は完全に表示
        Rectangle()
          .fill(.black)

        // 右側のグラデーション
        LinearGradient(
          gradient: Gradient(colors: [.black, .clear]),
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: 8)
      }
      .padding(.horizontal, -4)
    }
  }

  private func startAnimation() {
    offset = 0

    withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: false)) {
      offset = -(textWidth + spacing)
    }
  }
}

#Preview("Short Text") {
  MarqueeText("Short text")
    .font(.footnote.weight(.semibold))
    .frame(width: 200, height: 20)
    .border(Color.red)
}

#Preview("Long Text") {
  MarqueeText("This is a very long text that should scroll continuously in a loop")
    .font(.footnote.weight(.semibold))
    .frame(width: 200, height: 20)
    .border(Color.red)
}

#Preview("In Container") {
  VStack(spacing: 20) {
    MarqueeText("This is a very long title that needs to scroll")
      .frame(width: 150, height: 20)
      .background(Color.gray.opacity(0.2))

    MarqueeText("Short")
      .frame(width: 150, height: 20)
      .background(Color.gray.opacity(0.2))
  }
  .padding()
}
