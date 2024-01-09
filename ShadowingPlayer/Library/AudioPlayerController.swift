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

  }

  deinit {
    Log.debug("deinit \(String(describing: self))")
  }

  func prepare() throws {
    try engine.start()
  }

  func setSpeed(speed: Double) {

    assert(speed >= (1/32) && speed <= 32)

    pitchControl.rate = Float(speed)
  }

  func play() throws {

    if engine.isRunning == false {
      try engine.start()
    }

    audioPlayer.stop()
    audioPlayer.scheduleSegment(
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

        switch repeating {
        case .atEnd:
          if currentTime >= duration {
            seek(position: 0)
          }
        case .range(let start, let end):

          if currentTime >= end {
            seek(position: start)
          }

        case nil:

          if currentTime >= duration {
            pause()
          }

        }

      }

    }

    RunLoop.main.add(currentTimerForLoop!, forMode: .common)

    audioPlayer.play()
  }

  func pause() {
    currentTimerForLoop?.invalidate()
    currentTimerForLoop = nil
    audioPlayer.pause()
  }

  var duration: TimeInterval {
    Double(file.length) / file.fileFormat.sampleRate
  }

  var currentTime: TimeInterval? {

    guard let nodeTime = audioPlayer.lastRenderTime else {
      return nil
    }

    guard let playerTime = audioPlayer.playerTime(forNodeTime: nodeTime) else {
      return nil
    }

    let currentTime = (Double(playerTime.sampleTime + offset) / file.fileFormat.sampleRate)

    return currentTime
  }

  var offset: AVAudioFramePosition = 0

  func seek(position: TimeInterval) {

    let sampleRate = file.fileFormat.sampleRate

    let startFrame = AVAudioFramePosition(sampleRate * position)
    let endFrame = AVAudioFramePosition(duration * sampleRate)
    let frameCount = AVAudioFrameCount(endFrame - startFrame)

    guard frameCount > 0 else {
      audioPlayer.stop()
      return
    }

    offset = startFrame

    audioPlayer.stop()

    audioPlayer.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)

    audioPlayer.play()

  }

}

