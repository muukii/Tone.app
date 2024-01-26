import AVFoundation
import Verge

enum AudioPlayerControllerError: Error {
  case fileLengthIsZero
}

@MainActor
final class AudioPlayerController: StoreDriverType {

  enum Repeating {
    case atEnd
    case range(start: Double, end: Double)
  }

  struct State: StateType {
    var isPlaying: Bool = false
  }

  private let engine = AVAudioEngine()
  private let audioPlayer = AVAudioPlayerNode()

  private let pitchControl = AVAudioUnitTimePitch()

  private let file: AVAudioFile
  private var currentTimerForLoop: Timer?

  var repeating: Repeating? = nil

  let store: Store<State, Never> = .init(initialState: .init())

  init(file: AVAudioFile) throws {

    self.file = file

    guard file.length > 0 else {
      throw AudioPlayerControllerError.fileLengthIsZero
    }

    engine.attach(pitchControl)
    engine.attach(audioPlayer)

    let mainMixer = engine.mainMixerNode

    engine.connect(audioPlayer, to: pitchControl, format: nil)

    engine.connect(pitchControl, to: mainMixer, format: nil)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )

  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    Log.debug("deinit \(String(describing: self))")
  }

  @objc private func handleInterruption() {
    pause()
  }

  func prepare() throws {
    try engine.start()
  }

  func setSpeed(speed: Double) {

    assert(speed >= (1 / 32) && speed <= 32)

    pitchControl.rate = Float(speed)
  }

  func play() throws {

    commit {
      $0.isPlaying = true
    }

    if engine.isRunning == false {
      try engine.start()
    }

    audioPlayer.stop()

    _seek(frame: offset)

    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] in
        guard let self else { return }

        guard let currentFrame else {
          return
        }

        guard let currentTime = self.currentTime else {
          return
        }

        switch repeating {
        case .atEnd:
          if currentFrame + offset >= file.length {
            seek(position: 0)
          }
        case .range(let start, let end):

          if currentTime >= end {
            seek(position: start)
          }

        case nil:

          if currentTime >= file.duration {
            // reset cursor to beginning
            offset = 0
            pause()
          }

        }

      }

    }

    RunLoop.main.add(currentTimerForLoop!, forMode: .common)

    audioPlayer.play()
  }

  func pause() {

    commit {
      $0.isPlaying = false
    }

    currentTimerForLoop?.invalidate()
    currentTimerForLoop = nil
    offset = (currentFrame ?? 0) + offset
    audioPlayer.stop()
  }

  var currentFrame: AVAudioFramePosition? {
    guard let nodeTime = audioPlayer.lastRenderTime else {
      return nil
    }

    guard let playerTime = audioPlayer.playerTime(forNodeTime: nodeTime) else {
      return nil
    }

    return playerTime.sampleTime
  }

  var currentTime: TimeInterval? {

    guard let currentFrame = currentFrame else {
      return nil
    }

    let currentTime = (Double(currentFrame + offset) / file.fileFormat.sampleRate)

    return currentTime
  }

  var offset: AVAudioFramePosition = 0

  func seek(position: TimeInterval) {

    offset = file.frame(at: position)

    let isPlaying = audioPlayer.isPlaying

    if isPlaying {
      audioPlayer.stop()
    }

    _seek(position: position)

    if isPlaying {
      audioPlayer.play()
    }

  }

  private func _seek(frame: AVAudioFramePosition) {

    let startFrame = frame
    let rawFrameCount = file.length - frame

    guard rawFrameCount >= 0 else {
      Log.error("Frame count must be greater than 0 or equal.")
      return
    }

    let frameCount = AVAudioFrameCount(rawFrameCount)

    audioPlayer.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)

  }

  private func _seek(position: TimeInterval) {

    _seek(frame: file.frame(at: position))

  }

}

extension AVAudioFile {

  fileprivate var duration: TimeInterval {
    Double(length) / fileFormat.sampleRate
  }

  fileprivate func frame(at position: TimeInterval) -> AVAudioFramePosition {
    let sampleRate = fileFormat.sampleRate
    return AVAudioFramePosition(sampleRate * position)
  }

  fileprivate func frames(from position: TimeInterval) -> AVAudioFrameCount {
    let sampleRate = fileFormat.sampleRate

    let startFrame = AVAudioFramePosition(sampleRate * position)
    let endFrame = AVAudioFramePosition(length)
    let frameCount = AVAudioFrameCount(endFrame - startFrame)

    return frameCount
  }

}

#if DEBUG && canImport(SwiftUI)

import SwiftUI
import AppService

@MainActor
private struct AudioPlayerControllerPreview: View {

  let player: AudioPlayerController = try! .init(
    file: .init(forReading: Item.social.audioFileURL)//,
//    overlappingFile: .init(forReading: Item.overwhelmed.audioFileURL)
  )

  var body: some View {
    VStack {
      Button("Play") {
        try? player.play()
      }
      Button("Stop") {
        player.pause()
      }
    }
  }

}

#Preview {
  AudioPlayerControllerPreview()
}

#endif
