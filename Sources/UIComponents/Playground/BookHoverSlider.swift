import SwiftUI

struct HoverSlider<F: FormatStyle>: View
where F.FormatInput == Double, F.FormatOutput == String {

  @GestureState var hoverlingPoint: CGPoint?
  @State private var finalHoverlingPoint: CGPoint?
  @GestureState var distance: CGFloat = 0
  @State private var contentSize: CGSize = .zero
  @State private var textSize: CGSize = .zero

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
    mainContent
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
      .simultaneousGesture(dragGesture)
      .overlay(trackingOverlay)
      .animation(.bouncy, value: isTracking)
      .zIndex(isTracking ? 1 : 0)
      .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.3), trigger: isTracking)
      .sensoryFeedback(.impact(flexibility: .rigid), trigger: reachedBound)
      .sensoryFeedback(
        .impact(flexibility: .soft, intensity: 0.5),
        trigger: isResetting && value == defaultValue
      )
      .sensoryFeedback(.selection, trigger: value)
  }
  
  @ViewBuilder
  private var mainContent: some View {
    HStack {
      leftIndicator
      valueDisplay
      rightIndicator
    }
  }
  
  @ViewBuilder
  private var leftIndicator: some View {
    HStack(spacing: 2) {
      RoundedRectangle(cornerRadius: 4)
        .frame(width: 2)
        .padding(.vertical, 6)
      RoundedRectangle(cornerRadius: 4)
        .frame(width: 2)
        .padding(.vertical, 3)
    }
    .foregroundStyle(.secondary)
  }
  
  @ViewBuilder
  private var rightIndicator: some View {
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
  
  @ViewBuilder
  private var valueDisplay: some View {
    if isTracking {
      // Show placeholder rectangle when tracking
      RoundedRectangle(cornerRadius: 4)
        .fill(.tertiary.opacity(0.3))
        .frame(width: textSize.width, height: textSize.height)
    } else {
      // Show actual text when not tracking
      Text(formatStyle.format(value))
        .contentTransition(.numericText(value: value))
        .onGeometryChange(
          for: CGSize.self,
          of: \.size,
          action: { newValue in
            self.textSize = newValue
          }
        )
    }
  }
  
  private var dragGesture: some Gesture {
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

        // Check for reset based on Y-axis movement
        if value.translation.height > 50 {
          isResetting = true
          self.value = defaultValue
        } else {
          isResetting = false
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
        isResetting = false
      }
  }
  
  @ViewBuilder
  private var trackingOverlay: some View {
    if isTracking {
      floatingValueLabel
      trackBar
      resetButton
    }
  }
  
  @ViewBuilder
  private var floatingValueLabel: some View {
    Text(formatStyle.format(value))
      .contentTransition(.numericText(value: value))
      .font(.system(size: 16, weight: .bold))
      .foregroundStyle(.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(.regularMaterial)
      )
      .transition(JumpTransition(offsetY: -contentSize.height - 50))
  }
  
  @ViewBuilder
  private var trackBar: some View {
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
  }
  
  @ViewBuilder
  private var resetButton: some View {
    Image(systemName: "arrow.clockwise")
      .frame(width: 12, height: 12)
      .padding(12)
      .background(
        Circle()
          .fill(.regularMaterial)          
      )
      .contentShape(Circle())
      .scaleEffect(isResetting ? 1.2 : 1)
      .animation(.bouncy, value: isResetting)
      .sensoryFeedback(.impact(flexibility: .solid), trigger: isResetting)
      .transition(JumpTransition(offsetY: contentSize.height + 10))
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
