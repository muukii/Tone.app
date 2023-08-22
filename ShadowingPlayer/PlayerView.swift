import AVFoundation
import AudioKit
import SwiftUI
import SwiftUISupport
import WrapLayout

struct PlayerView: View {

  struct Term: Identifiable {
    var id: String { value }
    var value: String
  }

  @StateObject private var controller: PlayerController

  @State private var term: Term?
  @State private var focusing: DisplayCue?

  init(item: Item) {
    self._controller = .init(wrappedValue: try! PlayerController(item: item))
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

      ScrollView {
        ScrollViewReader { proxy in
          LazyVStack(alignment: .leading) {
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

                        if cue.backed.startTime < currentRange.startCue.backed.startTime {
                          currentRange.startCue = cue
                        } else if cue.backed.endTime > currentRange.endCue.backed.endTime {
                          currentRange.endCue = cue
                        }

                      } else {

                      }

                      controller.setRepeat(range: currentRange)

                    } else {
                      controller.setRepeat(range: .init(startCue: cue, endCue: cue))
                    }
                  } else {
                    controller.move(to: cue)
                  }
                }
              )
            }
          }
          .padding(.horizontal, 20)
          .onReceive(controller.$currentCue) { cue in

            guard let cue else { return }

            withAnimation(.bouncy) {
              proxy.scrollTo(cue.id, anchor: .center)
              focusing = cue
            }

          }
        }
      }

      Spacer(minLength: 20).fixedSize()

      control

    }
    .sheet(
      item: $term,
      onDismiss: {
        term = nil
      },
      content: { term in
        DefinitionView(term: term.value)
      }
    )
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }

  @ViewBuilder
  private var control: some View {
    VStack {
      HStack {

        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()

          if controller.isRepeating {
            controller.setRepeat(range: nil)
          } else {
            if let currentCue = controller.currentCue {
              controller.setRepeat(range: .init(startCue: currentCue, endCue: currentCue))
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

          ForEach([1.0, 0.95, 0.85, 0.8, 0.75, 0.65, 0.5, 0.4, 0.3, 0.2] as [Float], id: \.self) {
            value in
            Button {
              UIImpactFeedbackGenerator(style: .medium).impactOccurred()
              controller.setRate(value)
            } label: {
              HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "multiply")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 10)
                Text("\(value.description)")
                  .font(.body)
              }
            }
          }

        }
        .buttonStyle(.borderedProminent)
      }
      .contentMargins(20)
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

enum Preview_PlayerView: PreviewProvider {

  typealias TargetComponent = PlayerView

  static var previews: some View {

    Group {
      TargetComponent(item: .overwhelmed)
      TargetComponent(item: .make(name: "Why Aliens Might Already Be On Their Way To Us"))
    }

  }

}

#endif
