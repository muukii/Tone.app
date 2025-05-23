import SwiftUI
import AppService
import SteppedSlider

enum PlayerDisplayAction {
  case pin(DisplayCue)
  case move(to: DisplayCue)
  case setRepeat(range: PlayingRange)
}

struct PlayerControlPanel: View {

  enum Action {
    case onTapPin
    case onTapDetail
    case onStartRecord
    case onStopRecording
  }
  
  unowned let controller: PlayerController
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
    
    VStack {

      Spacer(minLength: 24).fixedSize()

      HStack(alignment: .center, spacing: 20) {

        // play or pause
        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }
          togglePlaying()
        } label: {
          Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
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

          if controller.isRepeating {
            controller.setRepeat(range: nil)
          } else {
            if let currentCue = controller.currentCue {
              var range = controller.makeRepeatingRange()
              range.select(cue: currentCue)
              controller.setRepeat(range: range)
            }
          }
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
              .opacity(controller.isRepeating ? 1 : 0)
          )
        }
        .frame(square: 50)
        .tint(Color.accentColor)

        // pin
        Button {
          onAction(.onTapPin)
        } label: {
          Image(systemName: "pin.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20)
            .foregroundColor(Color.primary)
        }
        .frame(square: 50)
        .buttonStyle(PlainButtonStyle())
        .disabled(controller.isRepeating == false)

        // detail
        Button {
          onAction(.onTapDetail)
        } label: {
          Image(systemName: "rectangle.portrait.and.arrow.forward")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 30)
            .foregroundColor(Color.primary)
        }
        .frame(square: 50)
        .buttonStyle(PlainButtonStyle())
        .disabled(controller.isRepeating == false)
        
        
        Button("Record / Stop") {
          if controller.isRecording {
            onAction(.onStopRecording)
          } else {
            onAction(.onStartRecord)
          }
        }
        .frame(square: 50)
        .buttonStyle(PlainButtonStyle())

      }

      Spacer(minLength: 16).fixedSize()

      VStack {
        Button {
          controller.rate = 1
        } label: {
          Text("\(String(format: "%.2f", controller.rate))")
            .font(.title3.monospacedDigit().bold())
            .contentTransition(.numericText(value: 1))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .tint(Color.accentColor)
        
        SteppedSlider(
          value: controller.$rate.binding,
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

      Spacer(minLength: 10).fixedSize()
    }
//    .onChange(
//      of: speed,
//      initial: true,
//      { _, value in
//        $state.driver.setRate(value)
//      }
//    )
    .scrollIndicators(.hidden)
    .background(.quinary)
    .onKeyPress(.space) {
      togglePlaying()
      return .handled
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
