import AVFoundation
import SwiftSubtitles
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

struct DisplayCue: Identifiable, Equatable {

  let id: String

  let backed: Subtitles.Cue

  init(backed: Subtitles.Cue) {
    self.backed = backed
    let s = backed.startTime
    self.id = "\(s.hour),\(s.minute),\(s.second),\(s.millisecond)"

  }
}

struct Item: Equatable, Identifiable {

  let id: String

  let audioFileURL: URL
  let subtitleFileURL: URL

  init(
    identifier: String,
    audioFileURL: URL,
    subtitleFileURL: URL
  ) {
    self.id = identifier
    self.audioFileURL = audioFileURL
    self.subtitleFileURL = subtitleFileURL
  }

  static var example: Self {
    make(name: "example")
  }

  static var overwhelmed: Self {
    make(name: "overwhelmed - Peter Mckinnon")
  }

  static func make(name: String) -> Self {

    let audioFileURL = Bundle.main.path(forResource: name, ofType: "mp3").map {
      URL(fileURLWithPath: $0)
    }!
    let subtitleFileURL = Bundle.main.path(forResource: name, ofType: "srt").map {
      URL(fileURLWithPath: $0)
    }!
    return .init(
      identifier: name,
      audioFileURL: audioFileURL,
      subtitleFileURL: subtitleFileURL
    )
  }
}

@MainActor
private final class PlayerController: ObservableObject {

  struct PlayingRange: Equatable {
    let startTime: TimeInterval
    let endTime: TimeInterval
  }

  @Published private var playingRange: PlayingRange?

  var isRepeating: Bool {
    playingRange != nil
  }

  @Published var isPlaying: Bool = false
  @Published var currentCue: DisplayCue?
  let cues: [DisplayCue]
  private let subtitles: Subtitles

  private let item: Item
  private var currentTimeObservation: NSKeyValueObservation?
  private var currentTimer: Timer?
  private let player: AVAudioPlayer

  init(item: Item) throws {
    self.item = item

    self.player = try AVAudioPlayer(contentsOf: item.audioFileURL)
    player.enableRate = true
    player.rate = 1.0

    self.subtitles = try Subtitles(fileURL: item.subtitleFileURL, encoding: .utf8)
    self.cues = subtitles.cues.map { .init(backed: $0) }
  }

  deinit {
    currentTimeObservation?.invalidate()
  }

  func play() {
    isPlaying = true
    player.play()

    currentTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
      @MainActor(unsafe) [weak self] _ in

      guard let self else { return }
      let c = self.findCurrentCue()
      if self.currentCue != c {
        self.currentCue = c
      }

      if let playingRange, playingRange.endTime < player.currentTime {
        player.currentTime = playingRange.startTime
      }

    }
  }

  func move(to cue: DisplayCue) {

    player.currentTime = cue.backed.startTime.timeInterval

    if isPlaying == false {
      play()
    }

    self.currentCue = cue

  }

  func setRepeat(in cue: DisplayCue?) {

    if let cue {

      playingRange = .init(
        startTime: cue.backed.startTime.timeInterval,
        endTime: cue.backed.endTime.timeInterval
      )
      move(to: cue)
    } else {
      playingRange = nil
    }
  }

  func setRate(_ rate: Float) {
    player.rate = rate
  }

  func pause() {
    isPlaying = false
    player.pause()

    currentTimer?.invalidate()
    currentTimer = nil
  }

  func findCurrentCue() -> DisplayCue? {

    let currentTime = player.currentTime

    let currentCue = cues.first { cue in

      (cue.backed.startTime.timeInterval..<cue.backed.endTime.timeInterval).contains(currentTime)

    }

    return currentCue
  }
}

extension AVAudioFile {

  var duration: Double {
    Double(length) / fileFormat.sampleRate
  }

}
extension AVAudioPlayerNode {

  var currentTime: TimeInterval {
    if let nodeTime = lastRenderTime, let playerTime = playerTime(forNodeTime: nodeTime) {
      return Double(playerTime.sampleTime) / playerTime.sampleRate
    }
    return 0
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
