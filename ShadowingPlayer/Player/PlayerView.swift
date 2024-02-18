import AVFoundation
import AppService
import SwiftUI
import SwiftUISupport
import SwiftUIRingSlider
import SwiftData

@MainActor
protocol PlayerDisplay: View {

  init(
    controller: PlayerController,
    pins: [PinEntity],
    actionHandler: @escaping @MainActor (PlayerAction) -> Void
  )
}

enum PlayerAction {
  case onPin(range: PlayingRange)
}

struct PlayerView<Display: PlayerDisplay>: View {

  struct Term: Identifiable {
    var id: String { value }
    var value: String
  }

  @ObjectEdge var controller: PlayerController
  private let actionHandler: @MainActor (PlayerAction) -> Void
  @State private var controllerForDetail: PlayerController?

  private let pins: [PinEntity]

  init(
    playerController: @escaping () -> PlayerController,
    pins: [PinEntity],
    actionHandler: @escaping @MainActor (PlayerAction) -> Void
  ) {
    self._controller = .init(wrappedValue: playerController())
    self.actionHandler = actionHandler
    self.pins = pins
  }

  var body: some View {
    //
    ZStack {

      Display(
        controller: controller,
        pins: pins,
        actionHandler: actionHandler
      )
    }
    .safeAreaInset(
      edge: .bottom,
      content: {
        PlayerControlPanel(
          controller: controller,
          onTapPin: {

            guard let range = controller.playingRange else {
              return
            }

            actionHandler(.onPin(range: range))

          },
          onTapDetail: {
            controllerForDetail = controller
          }
        )
      }
    )
    .navigationDestination(item: $controllerForDetail, destination: { controller in
      RepeatingView(controller: controller)
    })
    .onAppear {
      controller.activate()
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      controller.deactivate()
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .navigationBarTitleDisplayMode(.inline)

  }

}

enum PlayerDisplayAction {
  case pin(DisplayCue)
  case move(to: DisplayCue)
  case setRepeat(range: PlayingRange)
}

struct PlayerControlPanel: View {

  private let controller: PlayerController
  private let onTapPin: @MainActor () -> Void
  private let onTapDetail: @MainActor () -> Void

  @State var speed: Double = 1

  init(
    controller: PlayerController,
    onTapPin: @escaping @MainActor () -> Void,
    onTapDetail: @escaping @MainActor () -> Void
  ) {
    self.controller = controller
    self.onTapPin = onTapPin
    self.onTapDetail = onTapDetail
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
          onTapPin()
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
          onTapDetail()
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

      }

      Spacer(minLength: 16).fixedSize()

      VStack {
        Button {
          speed = 1.0
        } label: {
          Text("\(String(format: "%.2f", speed))")
            .font(.title3.monospacedDigit().bold())
            .contentTransition(.numericText(value: 1))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .tint(Color.accentColor)

        RingSlider(value: $speed, stride: 0.025, valueRange: 0.3...1)
      }

      Spacer(minLength: 10).fixedSize()
    }
    .onChange(
      of: speed,
      initial: true,
      { _, value in
        controller.setRate(value)
      }
    )
    .scrollIndicators(.hidden)
    .background(.quinary)
    .onKeyPress(.space) {
      togglePlaying()
      return .handled
    }
    .toolbar(content: {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Menu("Update subtitle") {
            Button("File") {
              // TODO:
            }
          }
        } label: {
          Image(systemName: "ellipsis")
        }
      }
    })
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

struct DefinitionView: UIViewControllerRepresentable {
  let term: String

  func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
    return UIReferenceLibraryViewController(term: term)
  }

  func updateUIViewController(
    _ uiViewController: UIReferenceLibraryViewController,
    context: Context
  ) {
  }
}

#if DEBUG

#Preview {
  Group {
    NavigationStack {
      PlayerView<PlayerListFlowLayoutView>(
        playerController: { try! .init(item: .social) },
        pins: [],
        actionHandler: { action in
        }
      )
    }

  }
  .accentColor(Color.pink)
  .tint(Color.pink)
}

#endif
