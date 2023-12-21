// MARK: - Recorder
import AVFAudio
import SwiftUI
import AppService

struct VoiceRecorderView: View {

  let controller: RecorderAndPlayer
  let tmp_controller = AudioPlayerController(
    file: try! .init(forReading: Item.overwhelmed.audioFileURL)
  )

  var body: some View {

    VStack {

      Button("play") {

        try! tmp_controller.play()

      }

      Button("Record Start") {
        do {
          try controller.startRecording()
        } catch {
          print(error)
        }
      }

      Button("Record Stop") {
        controller.stopRecording()
      }

      Button("Audio Play") {
        controller.playAudio()
      }

      Button("Audio Stop") {
        controller.stopAudio()
      }
    }

  }
}

final class RecorderAndPlayer {

  private var playerController: AudioPlayerController?
  private var recorderController: VoiceRecorderController?

  private var currentFilePath: URL?

  init() {

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
        playerController = .init(file: try .init(forReading: currentFilePath))
        try playerController!.prepare()
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

final class AudioPlayerController {

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let file: AVAudioFile

  init(file: AVAudioFile) {

    self.file = file

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
    player.scheduleSegment(file, startingFrame: .zero, frameCount: .init(file.length), at: nil)
    player.play()
  }

  func pause() {
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
