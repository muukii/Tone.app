// MARK: - Recorder
import AVFAudio
import AppService
import SwiftUI

struct VoiceRecorderView: View {

  @ObservableEdge var controller: RecorderAndPlayer = .init()

  var body: some View {

    VStack {

      Rectangle()
        .frame(square: 40)
        ._onButtonGesture(
          pressing: { isPressing in

            if isPressing {

              Task { @MainActor in
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

                try? await Task.sleep(for: .milliseconds(40))

                controller.stopAudio()
                try controller.startRecording()
              }
            } else {
              UINotificationFeedbackGenerator().notificationOccurred(.success)
              controller.stopRecording()
              controller.playAudio()
            }
            print(isPressing)
          },
          perform: {}
        )

      Button("Audio Stop") {
        controller.stopAudio()
      }
    }
    .onAppear {
      do {
        let instance = AVAudioSession.sharedInstance()
        try instance.setCategory(
          .playAndRecord,
          mode: .spokenAudio,
          options: [.allowBluetooth, .allowAirPlay, .mixWithOthers]
        )
      } catch {
        print(error)
      }
    }
    .onDisappear(perform: {
      do {
        let instance = AVAudioSession.sharedInstance()
        try instance.setCategory(
          .playback,
          mode: .default,
          options: [.allowBluetooth, .allowAirPlay, .mixWithOthers]
        )
      } catch {
        print(error)
      }
    })

  }
}

@MainActor
@Observable
final class RecorderAndPlayer {

  private var playerController: AudioPlayerController?
  private var recorderController: VoiceRecorderController?

  private var currentFilePath: URL?

  nonisolated init() {

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
    self.recorderController = .init(destination: filePath)

    Log.debug("makeNewFile: \(filePath)")
  }

  func startRecording() throws {

    makeNewFile()

    assert(recorderController != nil)

    try recorderController?.startRecording()
  }

  func stopRecording() {
    recorderController?.stopRecording()
  }

  func playAudio() {

    guard let currentFilePath else {
      return
    }

    do {

      if playerController == nil {

        if let newInstance = AudioPlayerController.init(file: try .init(forReading: currentFilePath)) {
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

        if self.currentTime == duration {
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

  private let destination: URL

  init(destination: URL) {
    self.destination = destination
  }

  func stopRecording() {
    recordingEngine.stop()
  }

  func startRecording() throws {

    let engine = recordingEngine

    let inputNode = engine.inputNode

    let inputFormat = inputNode.outputFormat(forBus: 0)

    let writingFile = try! AVAudioFile(
      forWriting: destination,
      settings: inputFormat.settings
    )

    inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [writingFile] (buffer, when) in
      do {
        // audioFileにバッファを書き込む
        try writingFile.write(from: buffer)
      } catch let error {
        print("audioFile.writeFromBuffer error:", error)
      }
    }

    try engine.start()
  }

}

#Preview {
  VoiceRecorderView()
}
