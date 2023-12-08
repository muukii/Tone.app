import AVFoundation
import AudioKit
import SwiftUI
import SwiftUISupport

protocol PlayerDisplay: View {

  init(
    cues: [DisplayCue],
    focusing: DisplayCue?,
    playingRange: PlayerController.PlayingRange?,
    isRepeating: Bool,
    actionHandler: @escaping (PlayerDisplayAction) -> Void
  )
}

struct PlayerView<Display: PlayerDisplay>: View {

  enum Action {
    case onPin(DisplayCue)
  }

  struct Term: Identifiable {
    var id: String { value }
    var value: String
  }

  private let controller: PlayerController

  @State private var focusing: DisplayCue?

  private let actionHandler: @MainActor (Action) -> Void

  init(
    playerController: PlayerController,
    actionHandler: @escaping @MainActor (Action) -> Void
  ) {
    self.controller = playerController
    self.actionHandler = actionHandler
  }

  private nonisolated static func chunk(
    text: String,
    identifier: some Hashable,
    isFocusing: Bool,
    isInRange: Bool,
    onSelect: @escaping () -> Void
  )
    -> some View
  {
    HStack {
      Text(text).font(.system(size: 24, weight: .bold, design: .default))
        .modifier(
          condition: isFocusing == false,
          identity: StyleModifier(scale: .init(width: 1.1, height: 1.1)),
          active: StyleModifier(opacity: 0.2)
        )
        .padding(6)
        .id(identifier)
        .textSelection(.enabled)

      Spacer()

      // Indicator
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          { () -> Color in
            if isInRange {
              return Color.blue
            } else if isFocusing {
              return Color.primary
            } else {
              return Color.primary.opacity(0.3)
            }
          }()
        )
        .frame(width: 40)
        ._onButtonGesture(
          pressing: { isPressing in },
          perform: {
            onSelect()
          }
        )
    }
  }

  var body: some View {

    VStack {

      Display(
        cues: controller.cues,
        focusing: focusing,
        playingRange: controller.playingRange,
        isRepeating: controller.isRepeating,
        actionHandler: { action in
          switch action {
          case .move(to: let cue):
            controller.move(to: cue)
          case .pin(let cue):
            actionHandler(.onPin(cue))
          case .setRepeat(let range):
            controller.setRepeat(range: range)
          }
        }
      )

      Spacer(minLength: 20).fixedSize()

      PlayerControlPanel(controller: controller)

    }
    //    .sheet(
    //      item: $term,
    //      onDismiss: {
    //        term = nil
    //      },
    //      content: { term in
    //        DefinitionView(term: term.value)
    //      }
    //    )
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }

  }

}

enum PlayerDisplayAction {
  case pin(DisplayCue)
  case move(to: DisplayCue)
  case setRepeat(range: PlayerController.PlayingRange)
}


struct PlayerControlPanel: View {

  private let controller: PlayerController

  init(controller: PlayerController) {
    self.controller = controller
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
      HStack {

        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }
          if controller.isPlaying {
            controller.pause()
          } else {
            controller.play()
          }
        } label: {
          if controller.isPlaying {
            Image(systemName: "pause.fill")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(square: 40)
              .foregroundColor(Color.primary)
          } else {
            Image(systemName: "play.fill")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(square: 40)
              .foregroundColor(Color.primary)
          }

        }

        Spacer(minLength: 35).fixedSize()

        // repeat button
        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }

          if controller.isRepeating {
            controller.setRepeat(range: nil)
          } else {
            if let currentCue = controller.currentCue {
              controller.setRepeat(range: .init(cue: currentCue))
            }
          }
        } label: {
          VStack {
            Image(systemName: "repeat")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 40)
              .foregroundColor(Color.primary)

            // indicator
            Circle()
              .opacity(controller.isRepeating ? 1 : 0)
              .frame(square: 5)
          }
        }

      }

      Spacer(minLength: 20).fixedSize()

      ScrollView(.horizontal) {
        HStack {

          ForEach([1.0, 0.85, 0.8, 0.75, 0.65, 0.5, 0.4] as [Double], id: \.self) {
            value in
            Button {
              MainActor.assumeIsolated {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
              }
              controller.setRate(Float(value))
            } label: {
              HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Self.fractionLabel(fraction: value))")
                  .font(.system(size: 16, weight: .bold, design: .default))
              }
              .aspectRatio(1, contentMode: .fill)
              .frame(square: 30)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(Color.orange)
          }

        }
        .buttonStyle(.borderedProminent)
      }
      .contentMargins(20)
    }
    .scrollIndicators(.hidden)
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
