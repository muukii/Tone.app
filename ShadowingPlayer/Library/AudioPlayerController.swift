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

    let format = file.processingFormat

    engine.attach(pitchControl)
    engine.attach(audioPlayer)

    let mainMixer = engine.mainMixerNode

    engine.connect(audioPlayer, to: pitchControl, format: format)

    engine.connect(pitchControl, to: mainMixer, format: format)

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

    _seek(frame: offsetSampleTime)

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
          if currentFrame + offsetSampleTime >= file.length {
            seek(position: 0)
          }
        case .range(let start, let end):

          if currentTime >= end {
            seek(position: start)
          }

        case nil:

          if currentTime >= file.duration {
            // reset cursor to beginning
            offsetSampleTime = 0
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
    offsetSampleTime = (currentFrame ?? 0) + offsetSampleTime
    audioPlayer.stop()
  }

  private var currentPlayerTime: AVAudioTime? {
    guard let nodeTime = audioPlayer.lastRenderTime else {
      return nil
    }

    guard let playerTime = audioPlayer.playerTime(forNodeTime: nodeTime) else {
      return nil
    }

    return playerTime
  }

  var currentFrame: AVAudioFramePosition? {
    return currentPlayerTime?.sampleTime
  }

  var currentTime: TimeInterval? {

    guard let currentPlayerTime = currentPlayerTime else {
      return nil
    }

    let currentTime = (Double(currentPlayerTime.sampleTime + offsetSampleTime) / currentPlayerTime.sampleRate)

    return currentTime

  }

  var offsetSampleTime: AVAudioFramePosition = 0

  func seek(position: TimeInterval) {

    offsetSampleTime = file.frame(at: position)

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

    print("seek \(frame)")

    var startFrame = frame
    if startFrame < 0 {
      Log.error("Frame must be greater than 0 or equal.")
      startFrame = 0
    }
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
    Double(length) / processingFormat.sampleRate
  }

  fileprivate func frame(at position: TimeInterval) -> AVAudioFramePosition {
    let sampleRate = processingFormat.sampleRate
    return AVAudioFramePosition(sampleRate * position)
  }

  fileprivate func frames(from position: TimeInterval) -> AVAudioFrameCount {
    let sampleRate = processingFormat.sampleRate

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
