import SteppedSlider
import SwiftUI

public struct PlayerControlPanelContent: View {

  public enum Action {
    case togglePlaying
    case toggleRepeat
    case pin
    case detail
    case startRecord
    case stopRecording
    case setRate(Double)
    case resetRate
  }

  let isPlaying: Bool
  let isRepeating: Bool
  let isRecording: Bool
  @Binding var rate: CGFloat
  let hasCurrentCue: Bool
  let namespace: Namespace.ID
  private let onAction: @MainActor (Action) -> Void

  public init(
    isPlaying: Bool,
    isRepeating: Bool,
    isRecording: Bool,
    rate: Binding<CGFloat>,
    hasCurrentCue: Bool,
    namespace: Namespace.ID,
    onAction: @escaping @MainActor @Sendable (Action) -> Void
  ) {
    self.isPlaying = isPlaying
    self.isRepeating = isRepeating
    self.isRecording = isRecording
    self._rate = rate
    self.hasCurrentCue = hasCurrentCue
    self.namespace = namespace
    self.onAction = onAction
  }

  private static func fractionLabel(fraction: CGFloat) -> String {
    if fraction < 1 {
      var text = String.init(format: "%0.2f", fraction)
      text.removeFirst()
      return text
    } else {
      return .init(format: "%.1f", fraction)
    }
  }

  public var body: some View {

    VStack(spacing: 8) {
      slider
      controls
    }
    .padding(.top, 24)
    .padding(.bottom, 10)
    .onKeyPress(.space) {
      onAction(.togglePlaying)
      return .handled
    }
  }

  private var controls: some View {
    HStack(alignment: .center, spacing: 20) {
      Group {
        // pin
        Button {
          onAction(.pin)
        } label: {
          Image(systemName: "bookmark.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18)
            .foregroundColor(Color.primary)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isRepeating == false)

        // play or pause
        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }
          onAction(.togglePlaying)
        } label: {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 28, height: 28)
            .foregroundColor(Color.primary)
            .contentTransition(.symbolEffect(.replace, options: .speed(2)))

        }
        .buttonStyle(PlainButtonStyle())
        
        // repeat button
        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }
          onAction(.toggleRepeat)
        } label: {
          ZStack {
            Image(systemName: "repeat")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 30, height: 30)
              .foregroundStyle(Color.primary)
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 10)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.accentColor.tertiary)
              .aspectRatio(1, contentMode: .fill)
              .opacity(isRepeating ? 1 : 0)
          )
        }
        .buttonStyle(PlainButtonStyle())

        RecordingButton(
          isRecording: isRecording,
          onRecord: {
            onAction(.startRecord)
          },
          onStop: {
            onAction(.stopRecording)
          }
        )

      }
      .frame(width: 50, height: 50)
      
//      .overlay { 
//        Color.red.opacity(0.1)          
//      }
    }

  }

  private var slider: some View {
    _Slider(
      onReset: {
        onAction(.resetRate)
      },
      rate: $rate
    )
    .padding(.horizontal, 20)
  }

}

private struct RecordingButton: View {

  var isRecording: Bool
  var onRecord: () -> Void
  var onStop: () -> Void

  var body: some View {
    Button(
      action: {
        if isRecording {
          onStop()
        } else {
          onRecord()
        }
      },
      label: {
      }
    )
    .buttonStyle(_ButtonStyle(isRecording: isRecording))
    .frame(width: 50, height: 50)
  }

  private struct _ButtonStyle: ButtonStyle {
    var isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
      Circle()
        .fill(.primary)
        .padding(5)
        .overlay(
          Circle()
            .stroke(.secondary, lineWidth: 4)
        )
        .foregroundStyle(.red)
        .frame(width: 36, height: 36)
        .aspectRatio(1, contentMode: .fill)
        .opacity(configuration.isPressed ? 0.6 : 1)
    }
  }
}

private struct _Slider: View {

  var onReset: () -> Void
  @Binding var rate: CGFloat

  var body: some View {
    VStack {
      Button(
        action: onReset,
        label: {
          Text("\(String(format: "%.2f", rate))")
            .font(.headline.monospacedDigit().bold())
            .contentTransition(.numericText(value: 1))
        }
      )
      .buttonStyle(.bordered)
      .buttonBorderShape(.roundedRectangle(radius: 8))
      .tint(Color.accentColor)

      SteppedSlider(
        value: $rate,
        range: 0.3...1,
        steps: 0.02,
        horizontalEdgeMask: .hidden,
        anchorView: {
          RoundedRectangle(cornerRadius: 1)
            .frame(width: 2, height: 20)
            .foregroundStyle(.tint)
        },
        segmentView: { _, _ in
          RoundedRectangle(cornerRadius: 1)
            .frame(width: 2, height: 20)
            .foregroundStyle(.tint.tertiary)
        },
        segmentOverlayView: { index, _ in
          EmptyView()
        },
        onEditing: {

        }
      )
      .frame(height: 40)

    }
  }

}

#Preview {
  @Previewable @Namespace var namespace

  return PlayerControlPanelContent(
    isPlaying: true,
    isRepeating: false,
    isRecording: false,
    rate: .constant(0.8),
    hasCurrentCue: true,
    namespace: namespace,
    onAction: { action in
      print("Preview action: \(action)")
    }
  )
}

#Preview("Recording State") {
  @Previewable @Namespace var namespace

  return PlayerControlPanelContent(
    isPlaying: false,
    isRepeating: true,
    isRecording: true,
    rate: .constant(1.0),
    hasCurrentCue: true,
    namespace: namespace,
    onAction: { action in
      print("Preview action: \(action)")
    }
  )
}

#Preview("Slow Rate") {
  @Previewable @Namespace var namespace

  return PlayerControlPanelContent(
    isPlaying: true,
    isRepeating: true,
    isRecording: false,
    rate: .constant(0.3),
    hasCurrentCue: false,
    namespace: namespace,
    onAction: { action in
      print("Preview action: \(action)")
    }
  )
}
