import AppService
import SteppedSlider
import SwiftUI

struct PlayerControlPanel: View {

  enum Action {
    case onTapPin
    case onTapDetail
    case onStartRecord
    case onStopRecording
  }

  let controller: PlayerController
  private let onAction: @MainActor (Action) -> Void

  let namespace: Namespace.ID

  init(
    controller: PlayerController,
    namespace: Namespace.ID,
    onAction: @escaping @MainActor (Action) -> Void
  ) {
    self.controller = controller
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

  var body: some View {
    PlayerControlPanelContent(
      isPlaying: controller.isPlaying,
      isRepeating: controller.isRepeating,
      isRecording: controller.isRecording,
      rate: controller.$rate.binding,
      hasCurrentCue: controller.currentCue != nil,
      namespace: namespace,
      onAction: { action in
        handleAction(action)
      }
    )
  }

  @MainActor
  private func handleAction(_ action: PlayerControlPanelContent.Action) {
    switch action {
    case .togglePlaying:
      togglePlaying()
    case .toggleRepeat:
      if controller.isRepeating {
        controller.setRepeat(range: nil)
      } else {
        if let currentCue = controller.currentCue {
          var range = controller.makeRepeatingRange()
          range.select(cue: currentCue)
          controller.setRepeat(range: range)
        }
      }
    case .pin:
      onAction(.onTapPin)
    case .detail:
      onAction(.onTapDetail)
    case .startRecord:
      onAction(.onStartRecord)
    case .stopRecording:
      onAction(.onStopRecording)
    case .setRate(let newRate):
      controller.rate = newRate
    case .resetRate:
      controller.rate = 1
    }
  }

  @MainActor
  private func togglePlaying() {
    if controller.isPlaying {
      controller.pause()
    } else {
      controller.play()
    }
  }

}

private struct PlayerControlPanelContent: View {

  enum Action {
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

  init(
    isPlaying: Bool,
    isRepeating: Bool,
    isRecording: Bool,
    rate: Binding<CGFloat>,
    hasCurrentCue: Bool,
    namespace: Namespace.ID,
    onAction: @escaping @MainActor (Action) -> Void
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

  var body: some View {

    VStack(spacing: 16) {
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
          .frame(square: 30)
          .matchedGeometryEffect(id: MainTabView.ComponentKey.playButton, in: namespace)
          .foregroundColor(Color.primary)
          .contentTransition(.symbolEffect(.replace, options: .speed(2)))

      }
      .frame(square: 50)

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
            .frame(width: 30)
            .foregroundStyle(Color.primary)
        }
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.accentColor.tertiary)
            .aspectRatio(1, contentMode: .fill)
            .opacity(isRepeating ? 1 : 0)
        )
      }
      .frame(square: 50)
      .tint(Color.accentColor)

      // pin
      Button {
        onAction(.pin)
      } label: {
        Image(systemName: "pin.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 20)
          .foregroundColor(Color.primary)
      }
      .frame(square: 50)
      .buttonStyle(PlainButtonStyle())
      .disabled(isRepeating == false)

      // detail
      Button {
        onAction(.detail)
      } label: {
        Image(systemName: "rectangle.portrait.and.arrow.forward")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 30)
          .foregroundColor(Color.primary)
      }
      .frame(square: 50)
      .buttonStyle(PlainButtonStyle())
      .disabled(isRepeating == false)

      Button("Record / Stop") {
        if isRecording {
          onAction(.stopRecording)
        } else {
          onAction(.startRecord)
        }
      }
      .frame(square: 50)
      .buttonStyle(PlainButtonStyle())

    }

  }

  private var slider: some View {
    VStack {
      Button {
        onAction(.resetRate)
      } label: {
        Text("\(String(format: "%.2f", rate))")
          .font(.title3.monospacedDigit().bold())
          .contentTransition(.numericText(value: 1))
      }
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
            .foregroundStyle(.tint.secondary)
        },
        segmentOverlayView: { index, _ in
          EmptyView()
        },
        onEditing: {}
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
