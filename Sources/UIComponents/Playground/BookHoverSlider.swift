import SwiftUI

private struct _Book: View {

  @GestureState var hoverlingPoint: CGPoint?
  @State private var finalHoverlingPoint: CGPoint?
  @GestureState var distance: CGFloat = 0
  @State private var contentSize: CGSize = .zero

  @State var current: Double? = nil
  @State var isResetting: Bool = false

  private var isTracking: Bool {
    current != nil
  }

  @State var value: Double = 0

  var body: some View {
    Text(Self.fractionLabel(fraction: value))
      .font(.system(size: 16, weight: .bold))
      .foregroundStyle(.primary)
      .padding(.horizontal, 6)
      .padding(.vertical, 8)
      .background(RoundedRectangle(cornerRadius: 8).fill(.tertiary))
      .onGeometryChange(
        for: CGSize.self,
        of: \.size,
        action: { newValue in
          self.contentSize = newValue
        }
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
          .updating($hoverlingPoint) { value, state, _ in
            state = value.location
          }
          .updating(
            $distance,
            body: { value, state, _ in
              state = value.translation.width
            }
          )
          .onChanged { value in

            if finalHoverlingPoint != nil {
              finalHoverlingPoint = nil
            }

            if value.translation.width == 0 {
              current = self.value
            }

            guard let current else {
              assertionFailure()
              return
            }
            
            if isResetting {
              self.value = 0
            } else {
              self.value = current + value.translation.width / 250
            }
          }
          .onEnded { value in
            current = nil

            if isResetting {
              self.value = 0
            }
          }
      )
      .overlay {
        if isTracking {
          ZStack {
            Rectangle()
              .frame(width: 200, height: 10)
              .offset(x: distance)
            Rectangle()
              .frame(width: 1, height: 30)
          }
          .transition(JumpTransition(offsetY: -contentSize.height - 10))

          TrackingView(
            hoverlingPoint: hoverlingPoint
          ) { isOn in
            Image(systemName: "arrow.clockwise")
              .frame(width: 12, height: 12)
              .foregroundStyle(.primary)
              .padding(12)
              .background(
                Circle()
                  .fill(isOn ? .secondary : .tertiary)
              )
              .contentShape(Circle())
              .scaleEffect(isOn ? 1.5 : 1)
              .animation(.bouncy, value: isOn)
              .sensoryFeedback(.impact(flexibility: .solid), trigger: isOn)
              .onChange(of: isOn, initial: true) { _, isOn in
                isResetting = isOn
              }
          }
          .transition(JumpTransition(offsetY: contentSize.height + 10))

        }
      }
      .animation(.bouncy, value: isTracking)
  }

  private static func fractionLabel(fraction: Double) -> String {
    if fraction < 1 {
      var text = String.init(format: "%0.2f", fraction)
      text.removeFirst()
      return text
    } else {
      return .init(format: "%.1f", fraction)
    }
  }

  private struct TrackingView<Content: View>: View {

    let content: @MainActor (Bool) -> Content
    @State private var targetFrame: CGRect = .zero
    private let hoverlingPoint: CGPoint?

    init(
      hoverlingPoint: CGPoint?,
      @ViewBuilder content: @escaping @MainActor (Bool) -> Content
    ) {
      self.hoverlingPoint = hoverlingPoint
      self.content = content
    }

    var body: some View {

      let isOn =
        if let hoverlingPoint {
          targetFrame.contains(hoverlingPoint)
        } else {
          false
        }

      content(isOn)
        .onGeometryChange(
          for: CGRect.self,
          of: { proxy in
            proxy.frame(in: .global)
          },
          action: { value in
            targetFrame = value
          }
        )

    }
  }

  private struct JumpTransition: Transition {

    private let offsetY: CGFloat

    init(offsetY: CGFloat = 0) {
      self.offsetY = offsetY
    }

    func body(content: Content, phase: TransitionPhase) -> some View {

      content
        .scaleEffect(
          {
            switch phase {
            case .willAppear:
              return CGSize(width: 0.5, height: 0.5)
            case .identity:
              return CGSize(width: 1, height: 1)
            case .didDisappear:
              return CGSize(width: 0.5, height: 0.5)
            }
          }()
        )
        .opacity(
          {
            switch phase {
            case .willAppear:
              return 0
            case .identity:
              return 1
            case .didDisappear:
              return 0
            }
          }()
        )
        .blur(
          radius: {
            switch phase {
            case .willAppear:
              return 10
            case .identity:
              return 0
            case .didDisappear:
              return 10
            }
          }()
        )
        .offset(
          y: {
            switch phase {
            case .willAppear:
              return 0
            case .identity:
              return offsetY
            case .didDisappear:
              return 0
            }
          }()
        )
    }

  }

}

#Preview("HoverSlider") {
  _Book()
    .foregroundStyle(.blue)
}
