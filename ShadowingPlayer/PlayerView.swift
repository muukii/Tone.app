import AVFoundation
import SwiftSubtitles
import SwiftUI
import SwiftUISupport

struct PlayerView: View {

  @StateObject private var controller = try! PlayerController(item: .example)

  var body: some View {

    VStack {

      ScrollView {
        ScrollViewReader { proxy in
          LazyVStack(alignment: .leading) {
            ForEach(controller.cues) { cue in
              Text(cue.backed.text)
                .modifier(
                  condition: cue != controller.currentCue,
                  identity: StyleModifier.identity,
                  active: StyleModifier(opacity: 0.5, scale: .init(width: 0.6, height: 0.6))
                )
                .font(.system(size: 34, weight: .bold, design: .default))

                .padding(6)

                .padding(.vertical, cue != controller.currentCue ? -20 : 0)
                ._onButtonGesture(
                  pressing: { isPressing in },
                  perform: {
                    controller.move(to: cue)
                  }
                )
//                .background(Color.red)
            }
          }
          .animation(
            .interactiveSpring(response: 0.8, dampingFraction: 1, blendDuration: 0),
            value: controller.currentCue
          )
          .onReceive(controller.$currentCue) { cue in

            guard let cue else { return }

            withAnimation(.interactiveSpring(response: 0.8, dampingFraction: 1, blendDuration: 0)) {
              proxy.scrollTo(cue.id, anchor: .center)
            }

          }
        }
      }

      HStack {
        Button("Play") {
          controller.play()
        }
        Text("isPlaying, \(controller.isPlaying.description)")
        Button("Pause") {
          controller.pause()
        }
      }
    }
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

struct Item: Equatable {

  let audioFileURL: URL
  let subtitleFileURL: URL

  init(audioFileURL: URL, subtitleFileURL: URL) {
    self.audioFileURL = audioFileURL
    self.subtitleFileURL = subtitleFileURL
  }

  static var example: Self {
    let audioFileURL = Bundle.main.path(forResource: "example", ofType: "mp3").map {
      URL(fileURLWithPath: $0)
    }!
    let subtitleFileURL = Bundle.main.path(forResource: "example", ofType: "srt").map {
      URL(fileURLWithPath: $0)
    }!
    return .init(audioFileURL: audioFileURL, subtitleFileURL: subtitleFileURL)
  }
}

@MainActor
private final class PlayerController: ObservableObject {

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
    player.rate = 0.5

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
    }
  }

  func move(to cue: DisplayCue) {

    player.currentTime = cue.backed.startTime.timeInterval

    if isPlaying == false {
      play()
    }

    self.currentCue = cue

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

      cue.backed.startTime.timeInterval >= currentTime
        && cue.backed.endTime.timeInterval > currentTime

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
      TargetComponent()
    }

  }

}

#endif
