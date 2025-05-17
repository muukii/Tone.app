import AVFoundation
import MediaPlayer
import StateGraph

enum AudioPlayerControllerError: Error {
  case fileLengthIsZero
}

@MainActor
final class AudioPlayerController: NSObject {

  enum Repeating {
    case atEnd
    case range(start: Double, end: Double)
  }

  @GraphStored
  var isPlaying: Bool = false
  var isAppInBackground: Bool = false

  private var engine: AVAudioEngine?
  private let audioPlayer = AVAudioPlayerNode()

  private let pitchControl = AVAudioUnitTimePitch()

  private let file: AVAudioFile
  private var currentTimerForLoop: Timer?

  var repeating: Repeating? = nil

  init(file: AVAudioFile) throws {

    self.file = file

    guard file.length > 0 else {
      throw AudioPlayerControllerError.fileLengthIsZero
    }
    
    super.init()

    // Listen for audio session interruptions (e.g., incoming call)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )
    // Listen for route changes (e.g., headphones unplug or Bluetooth device removed)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance()
    )
  }

  deinit {
    // Remove observers for notifications and remote commands
    NotificationCenter.default.removeObserver(self)
    Log.debug("deinit \(String(describing: self))")
  }

  @objc private func handleInterruption() {
    pause()
  }
  
  /// Handle audio route changes, such as headphones being unplugged or Bluetooth device removed
  @objc private func handleRouteChange(_ notification: Notification) {
    guard let info = notification.userInfo,
          let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
          reason == .oldDeviceUnavailable else {
      return
    }
    pause()
  }

  func prepare() throws {
    try engine?.start()
  }

  func setSpeed(speed: Double) {

    assert(speed >= (1 / 32) && speed <= 32)

    pitchControl.rate = Float(speed)
  }
  
  private func createEngine() {
    
    // making AVAudioEngine triggers AVAudioSession to start
    
    let format = file.processingFormat

    let newEngine = AVAudioEngine()
    self.engine = newEngine
    
    newEngine.attach(pitchControl)
    newEngine.attach(audioPlayer)
    
    let mainMixer = newEngine.mainMixerNode
    
    newEngine.connect(audioPlayer, to: pitchControl, format: format)
    newEngine.connect(pitchControl, to: mainMixer, format: format)    
  }

  func play() throws {
    
    if engine == nil {
      createEngine()
    }

    isPlaying = true

    if engine?.isRunning == false {
      try engine?.start()
    }

    audioPlayer.stop()

    _seek(frame: offsetSampleTime)

    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] in

        guard let self else { return }

        guard let currentFrame = self.currentFrame else {
          return
        }

        guard let currentTime = self.currentTime else {
          return
        }

        switch self.repeating {
        case .atEnd:
          if currentFrame + self.offsetSampleTime >= self.file.length {
            self.seek(position: 0)
          }
        case .range(let start, let end):

          if currentTime >= end {
            self.seek(position: start)
          }

        case nil:

          if currentTime >= self.file.duration {
            // reset cursor to beginning
            self.offsetSampleTime = 0
            self.pause()
          }

        }

      }

    }

    RunLoop.main.add(currentTimerForLoop!, forMode: .common)

    audioPlayer.play()
  }

  func pause() {

    isPlaying = false

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

    let currentTime =
      (Double(currentPlayerTime.sampleTime + offsetSampleTime) / currentPlayerTime.sampleRate)

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
    
    guard isPlaying else {
      return
    }

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
    file: .init(forReading: Item.social.audioFileURL)  //,
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
