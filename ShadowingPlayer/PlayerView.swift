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
    onSelect: @escaping () -> Void
  )
    -> some View
  {
    HStack {
      Text(text).font(.system(size: 30, weight: .bold, design: .default))
        .modifier(
          condition: isFocusing == false,
          identity: StyleModifier(scale: .init(width: 1.1, height: 1.1)),
          active: StyleModifier(opacity: 0.2)
        )
        .padding(6)
        .id(identifier)
        .textSelection(.enabled)

      Spacer()

      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(isFocusing ? Color.primary : Color.primary.opacity(0.3))
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
                onSelect: {
                  if controller.isRepeating {
                    controller.setRepeat(in: cue)
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

            withAnimation(.interactiveSpring(response: 0.8, dampingFraction: 1, blendDuration: 0)) {
              proxy.scrollTo(cue.id, anchor: .center)
              focusing = cue
            }

          }
        }
      }

      Spacer(minLength: 20).fixedSize()

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

        Spacer(minLength: 45).fixedSize()

        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()

          if controller.isRepeating {
            controller.setRepeat(in: nil)
          } else {
            if let currentCue = controller.currentCue {
              controller.setRepeat(in: currentCue)
            }
          }
        } label: {
          VStack {
            Image(systemName: "repeat")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 40)
              .foregroundColor(Color.primary)

            Circle()
              .opacity(controller.isRepeating ? 1 : 0)
              .frame(square: 5)
          }
        }

      }

      Spacer(minLength: 40).fixedSize()

      HStack {
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          controller.setRate(0.5)
        } label: {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "multiply")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 10)
            Text("0.5")
              .font(.body)
          }
        }

        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          controller.setRate(0.75)
        } label: {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "multiply")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 10)
            Text("0.75")
              .font(.body)
          }
        }

        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          controller.setRate(0.85)
        } label: {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "multiply")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 10)
            Text("0.85")
              .font(.body)
          }
        }

        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          controller.setRate(1)
        } label: {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "multiply")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 10)
            Text("1")
              .font(.body)
          }
        }

      }
      .buttonStyle(.borderedProminent)
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
