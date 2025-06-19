import SwiftUI

struct HoverSlider<F: FormatStyle>: View
where F.FormatInput == Double, F.FormatOutput == String {

  @GestureState var hoverlingPoint: CGPoint?
  @State private var finalHoverlingPoint: CGPoint?
  @GestureState var distance: CGFloat = 0
  @State private var contentSize: CGSize = .zero

  @State var current: Double? = nil
  @State var isResetting: Bool = false

  private var isTracking: Bool {
    current != nil
  }

  @Binding var value: Double
  @State private var reachedBound: Bool = false

  let range: ClosedRange<Double>
  let formatStyle: F
  let defaultValue: Double

  init(
    value: Binding<Double>,
    range: ClosedRange<Double> = 0...1,
    defaultValue: Double? = nil,
    format: F
  ) {
    self._value = value
    self.range = range
    self.defaultValue = defaultValue ?? range.lowerBound
    self.formatStyle = format
  }

  init(
    value: Binding<Double>,
    range: ClosedRange<Double> = 0...1,
    defaultValue: Double? = nil
  ) where F == FloatingPointFormatStyle<Double> {
    self.init(
      value: value,
      range: range,
      defaultValue: defaultValue,
      format: FloatingPointFormatStyle<Double>()
    )
  }

  private var normalizedValue: Double {
    let rangeSize = range.upperBound - range.lowerBound
    guard rangeSize > 0 else { return 0 }
    return (value - range.lowerBound) / rangeSize
  }

  var body: some View {
    HStack {
      HStack(spacing: 2) {
        RoundedRectangle(cornerRadius: 4)
          .frame(width: 2)
          .padding(.vertical, 6)
        RoundedRectangle(cornerRadius: 4)
          .frame(width: 2)
          .padding(.vertical, 3)
      }
      .foregroundStyle(.secondary)

      Text(formatStyle.format(value))
        .contentTransition(.numericText(value: value))

      HStack(spacing: 2) {

        RoundedRectangle(cornerRadius: 4)
          .frame(width: 2)
          .padding(.vertical, 3)
        RoundedRectangle(cornerRadius: 4)
          .frame(width: 2)
          .padding(.vertical, 6)
      }
      .foregroundStyle(.secondary)
    }
    .animation(.snappy, value: value)
    .fixedSize(horizontal: true, vertical: true)
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

          let previousValue = self.value

          if isResetting && value.translation.height > 5 {
            self.value = defaultValue
          } else {
            let delta = (range.upperBound - range.lowerBound) * value.translation.width / 250
            let newValue = max(range.lowerBound, min(range.upperBound, current + delta))

            // Check if we hit the bounds
            if (previousValue != range.lowerBound && newValue == range.lowerBound)
              || (previousValue != range.upperBound && newValue == range.upperBound)
            {
              self.reachedBound = true
            }
            self.value = newValue
          }
        }
        .onEnded { value in
          current = nil

          if isResetting {
            self.value = defaultValue
          }
        }
    )
    .overlay {
      if isTracking {
        let width: CGFloat = 200

        ZStack {
          // Background track
          RoundedRectangle(cornerRadius: 2)
            .fill(.quaternary)
            .frame(width: width, height: 4)

          // Filled portion
          RoundedRectangle(cornerRadius: 2)
            .fill(.primary)
            .frame(width: normalizedValue * 200, height: 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: width, height: 4)

          // Current position indicator
          Circle()
            .fill(.primary)
            .frame(width: 12, height: 12)
            .offset(x: (normalizedValue - 0.5) * width)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)       
        .fixedSize()
        .background(
          Capsule()
            .fill(.regularMaterial)
        )
        .transition(JumpTransition(offsetY: -contentSize.height - 6))

        TrackingView(
          hoverlingPoint: hoverlingPoint
        ) { isOn in
          Image(systemName: "arrow.clockwise")
            .frame(width: 12, height: 12)
            .foregroundStyle(.primary)
            .padding(12)
            .background(
              Circle()
                .fill(.regularMaterial)
              //                  .overlay(
              //                    Circle()
              //                      .fill(isOn ? Color.secondary.opacity(0.3) : Color.tertiary.opacity(0.3))
              //                  )
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
    .zIndex(isTracking ? 1 : 0)
    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.3), trigger: isTracking)
    .sensoryFeedback(.impact(flexibility: .rigid), trigger: reachedBound)
    .sensoryFeedback(
      .impact(flexibility: .soft, intensity: 0.5),
      trigger: isResetting && value == defaultValue
    )
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
  struct PreviewContent: View {
    @State private var value1: Double = 0.5
    @State private var value2: Double = 0.3
    @State private var value3: Double = 500
    @State private var value4: Double = 0
    @State private var value5: Double = 50

    var body: some View {
      VStack(spacing: 20) {
        // Default floating point format
        HoverSlider(value: $value1, range: 0...1)
          .foregroundStyle(.blue)

        // Percentage format
        HoverSlider(
          value: $value2,
          range: 0...1,
          format: FloatingPointFormatStyle<Double>.Percent()
        )
        .foregroundStyle(.green)

        // Currency format
        HoverSlider(
          value: $value3,
          range: 0...1000,
          format: FloatingPointFormatStyle<Double>.Currency(code: "USD")
        )
        .foregroundStyle(.orange)

        // Number with specific fraction digits
        HoverSlider(
          value: $value4,
          range: -50...50,
          format: FloatingPointFormatStyle<Double>()
            .precision(.fractionLength(1))
        )
        .foregroundStyle(.red)

        // Percent with precision
        HoverSlider(
          value: $value5,
          range: 0...100,
          format: FloatingPointFormatStyle<Double>.Percent()
            .precision(.fractionLength(0))
        )
        .foregroundStyle(.purple)
      }
      .padding()
    }
  }

  return PreviewContent()
}
