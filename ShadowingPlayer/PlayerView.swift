import AVFoundation
import AudioKit
import SwiftUI
import SwiftUISupport
import WrapLayout

struct PlayerView: View {

  enum Action {
    case onPin(DisplayCue)
  }

  struct Term: Identifiable {
    var id: String { value }
    var value: String
  }

  private let controller: PlayerController

//  @State private var term: Term?
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
        .fill({ () -> Color in
          if isInRange {
            return Color.blue
          } else if isFocusing {
            return Color.primary
          } else {
            return Color.primary.opacity(0.3)
          }
        }())
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

      ScrollViewReader { proxy in
        List {
          ForEach(controller.cues) { cue in
            PlayerView.chunk(
              text: cue.backed.text,
              identifier: cue.id,
              isFocusing: cue == focusing,
              isInRange: controller.playingRange?.contains(cue) ?? false,
              onSelect: {
                if controller.isRepeating {

                  if var currentRange = controller.playingRange {

                    if currentRange.isExact(with: cue) {
                      // selected current active range
                      return
                    }

                    if currentRange.contains(cue) == false {

                      currentRange.add(cue: cue)

                    } else {
                      currentRange.remove(cue: cue)
                    }

                    controller.setRepeat(range: currentRange)

                  } else {
                    controller.setRepeat(range: .init(cue: cue))
                  }
                } else {
                  controller.move(to: cue)
                }
              }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
            .contextMenu {
              Button("Pin") {
                actionHandler(.onPin(cue))
              }
            }
          }
        }
        .listStyle(.plain)
        .onChange(of: controller.currentCue, { oldValue, cue in

          guard let cue else { return }

          withAnimation(.bouncy) {
            proxy.scrollTo(cue.id, anchor: .center)
            focusing = cue
          }

        })
      }

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

struct PlayerListDisplayView: View {

  let cues: [DisplayCue]
  let focusing: DisplayCue?
  let playingRange: PlayerController.PlayingRange?
  let isRepeating: Bool

  let actionHandler: (PlayerDisplayAction) -> Void

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(cues) { cue in
          Self.chunk(
            text: cue.backed.text,
            identifier: cue.id,
            isFocusing: cue == focusing,
            isInRange: playingRange?.contains(cue) ?? false,
            onSelect: {
              if isRepeating {

                if var currentRange = playingRange {

                  if currentRange.isExact(with: cue) {
                    // selected current active range
                    return
                  }

                  if currentRange.contains(cue) == false {

                    currentRange.add(cue: cue)

                  } else {
                    currentRange.remove(cue: cue)
                  }

                  actionHandler(.setRepeat(range: currentRange))

                } else {

                  actionHandler(.setRepeat(range: .init(cue: cue)))
                }
              } else {
                actionHandler(.move(to: cue))
              }
            }
          )
          .listRowSeparator(.hidden)
          .listRowInsets(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
          .contextMenu {
            Button("Pin") {
              actionHandler(.pin(cue))
            }
          }
        }
      }
      .listStyle(.plain)
      .onChange(of: focusing, { oldValue, cue in

        guard let cue else { return }

        withAnimation(.bouncy) {
          proxy.scrollTo(cue.id, anchor: .center)
        }

      })
    }

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
        .fill({ () -> Color in
          if isInRange {
            return Color.blue
          } else if isFocusing {
            return Color.primary
          } else {
            return Color.primary.opacity(0.3)
          }
        }())
        .frame(width: 40)
        ._onButtonGesture(
          pressing: { isPressing in },
          perform: {
            onSelect()
          }
        )
    }
  }
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

#if DEBUG

#Preview {
  Group {

  }
}

#endif
