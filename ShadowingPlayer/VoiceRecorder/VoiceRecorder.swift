// MARK: - Recorder
import AVFAudio
import AppService
import SwiftUI
import TipKit

struct SampleTip: Tip {
  var title: Text {
    Text("Record and playback")
  }


  var message: Text? {
    Text("Tap and hold to record")
  }

  var image: Image? {
    nil
  }

}

@MainActor
struct VoiceRecorderView: View {

  @ObservableEdge var controller: RecorderAndPlayer = .init()

  // TMP
  @State var isPlaying: Bool = false

  var body: some View {

    VStack {

      ScrollView(.horizontal) {

        LazyHStack {
          ForEach(controller.recordedItems) { item in
            Text(item.duration, format: .time(pattern: .minuteSecond))
              .font(.headline.bold().monospacedDigit())
              .foregroundStyle(.primary)
              .padding(12)
              .background {
                RoundedRectangle(cornerRadius: 16)
                  .foregroundStyle(.tertiary)
              }

          }

        }
        .backgroundStyle(.tint)
        .foregroundStyle(.tint)

      }
      .safeAreaPadding(.horizontal, 24)

      Spacer()

      TipView(SampleTip(), arrowEdge: .bottom) { a in

      }

      RecordingButtonButton { isPressing in
        if isPressing {
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))

            controller.stopAudio()
            isPlaying = false
            try controller.startRecording()
          }
        } else {
          controller.stopRecording()
          controller.playAudio()
          isPlaying = true
        }
      }

      // play or pause
      Button {
        MainActor.assumeIsolated {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        if isPlaying {
          controller.stopAudio()
          isPlaying = false
        } else {
          controller.playAudio()
          isPlaying = true
        }
      } label: {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(square: 30)
          .foregroundStyle(.secondary)
          .contentTransition(.symbolEffect(.replace, options: .speed(2)))

      }
      .frame(square: 50)

    }
    .onAppear {
      controller.activate()
    }
    .onDisappear {
      controller.deactivate()
    }

  }
}

private struct RecordingButtonButton: View {

  @State var isPressing: Bool = false

  var onPressing: (Bool) -> Void

  var body: some View {

    Circle()
      .frame(square: 80)
      .foregroundStyle(.primary)
      .animation(.snappy) { v in
        v.opacity(isPressing ? 0.2 : 1)
      }
      .padding(7)
      .overlay {
        Circle()
          .stroke(.secondary, lineWidth: 8)
      }
      .foregroundStyle(.tint)
      .sensoryFeedback(
        trigger: isPressing,
        { oldValue, newValue in
          if oldValue == false, newValue == true {
            return .impact(flexibility: .rigid, intensity: 1)
          }

          if oldValue == true, newValue == false {
            return .impact(flexibility: .solid, intensity: 0.8)
          }

          return nil
        }
      )
      ._onButtonGesture(
        pressing: { isPressing in
          self.isPressing = isPressing
          onPressing(isPressing)
        },
        perform: {

        }
      )

  }

}

#Preview {
  RecordingButtonButton(onPressing: { _ in })
}

@MainActor
@Observable
final class RecorderAndPlayer {

  struct Recorded: Equatable, Identifiable {

    var id: URL {
      filePath
    }

    let duration: Duration
    let filePath: URL

  }

  private(set) var recordedItems: [Recorded] = []

  private var playerController: AudioPlayerController?
  private var recorderController: VoiceRecorderController?

  private var currentFilePath: URL?

  private var subscription: NSObjectProtocol?

  init() {

  }

  deinit {
    MainActor.assumeIsolated {
      deactivate()
    }
  }

  func activate() {
    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(true)

      //      instance.currentRoute.outputs.contains {
      //        $0.portType == .headphones
      //      }

      print(instance.currentRoute)
      //        try instance.overrideOutputAudioPort(.speaker)
      try instance.setCategory(
        .playAndRecord,
        mode: .spokenAudio,
        options: [.allowBluetooth, .allowAirPlay, .mixWithOthers, .defaultToSpeaker]
      )
    } catch {
      print(error)
    }

    subscription = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { n in
      // TODO:
    }
  }

  func deactivate() {

    NotificationCenter.default.removeObserver(subscription as Any)

    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(false)
    } catch {
      print(error)
    }
  }

  func makeNewFile() {

    let id = UUID().uuidString

    let documentDir = URL.temporaryDirectory
    let filePath = documentDir.appending(path: "recording_\(id).caf")

    self.currentFilePath = filePath

    self.playerController?.pause()
    self.playerController = nil

    self.recorderController?.stopRecording()
    self.recorderController = nil

    do {
      self.recorderController = try .init(destination: filePath)
    } catch {
      Log.error("\(error.localizedDescription)")
    }

    Log.debug("makeNewFile: \(filePath)")
  }

  func startRecording() throws {

    makeNewFile()

    assert(recorderController != nil)

    try recorderController?.startRecording()
  }

  func stopRecording() {

    guard let recorderController = recorderController else {
      return
    }

    recorderController.stopRecording()

    let file = recorderController.writingFile

    let duration = Double(file.length) / file.fileFormat.sampleRate

    recordedItems.append(
      Recorded(duration: .seconds(duration), filePath: file.url)
    )
  }

  func playAudio() {

    guard let currentFilePath else {
      return
    }

    do {

      if playerController == nil {

        if let newInstance = AudioPlayerController.init(
          file: try .init(forReading: currentFilePath)
        ) {
          playerController = newInstance
          try playerController?.prepare()
        } else {
          // from some reason, can not play the audio file.
          return
        }
      }

      try playerController!.play()

    } catch {

      print(error)

    }
  }

  func stopAudio() {
    playerController?.pause()
  }

}

@MainActor
final class AudioPlayerController {

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let file: AVAudioFile
  private var currentTimerForLoop: Timer?

  init?(file: AVAudioFile) {

    self.file = file

    guard file.length > 0 else {
      return nil
    }

    engine.attach(player)
    let mainMixer = engine.mainMixerNode
    engine.connect(player, to: mainMixer, format: file.processingFormat)
  }

  deinit {
    Log.debug("deinit \(String(describing: self))")
  }

  func prepare() throws {
    try engine.start()
  }

  func play() throws {

    if engine.isRunning == false {
      try engine.start()
    }

    player.stop()
    player.scheduleSegment(
      file,
      startingFrame: .zero,
      frameCount: .init(file.length),
      at: nil
    )

    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] in
        guard let self else { return }

        guard let currentTime = self.currentTime else {
          return
        }

        if currentTime >= duration {
          seek(position: 0)
        }
      }

    }

    RunLoop.main.add(currentTimerForLoop!, forMode: .common)

    player.play()
  }

  func pause() {
    currentTimerForLoop?.invalidate()
    currentTimerForLoop = nil
    player.pause()
  }

  var duration: TimeInterval {
    Double(file.length) / file.fileFormat.sampleRate
  }

  var currentTime: TimeInterval? {

    guard let nodeTime = player.lastRenderTime else {
      return nil
    }

    guard let playerTime = player.playerTime(forNodeTime: nodeTime) else {
      return nil
    }

    let currentTime = (Double(playerTime.sampleTime) / file.fileFormat.sampleRate)

    return currentTime
  }

  func seek(position: TimeInterval) {

    let sampleRate = file.fileFormat.sampleRate

    let startFrame = AVAudioFramePosition(sampleRate * position)
    let endFrame = AVAudioFramePosition(duration * sampleRate)
    let frameCount = AVAudioFrameCount(endFrame - startFrame)

    guard frameCount > 0 else {
      player.stop()
      return
    }

    player.stop()

    player.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)

    player.play()

  }

}

final class VoiceRecorderController {

  private let recordingEngine = AVAudioEngine()

  let writingFile: AVAudioFile

  init(destination: URL) throws {

    let inputFormat = recordingEngine.inputNode.outputFormat(forBus: 0)

    self.writingFile = try AVAudioFile(
      forWriting: destination,
      settings: inputFormat.settings
    )
  }

  func stopRecording() {
    recordingEngine.stop()
  }

  func startRecording() throws {

    recordingEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) {
      [writingFile] (buffer, when) in
      do {
        // audioFileにバッファを書き込む
        try writingFile.write(from: buffer)
      } catch let error {
        print("audioFile.writeFromBuffer error:", error)
      }
    }

    try recordingEngine.start()
  }

}

#Preview {
  VoiceRecorderView()
    .tint(.yellow)
    .onAppear(perform: {
      try? Tips.resetDatastore()
      try? Tips.configure([
        .displayFrequency(.immediate),

      ])
    })
}
