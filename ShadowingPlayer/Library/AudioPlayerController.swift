import AVFoundation

enum AudioPlayerControllerError: Error {
  case fileLengthIsZero
}

@MainActor
final class AudioPlayerController {

  private let engine = AVAudioEngine()
  private let audioPlayer = AVAudioPlayerNode()

  private let pitchControl = AVAudioUnitTimePitch()

  private let file: AVAudioFile
  private var currentTimerForLoop: Timer?

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

        if currentTime >= duration {
          seek(position: 0)
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

    let currentTime = (Double(playerTime.sampleTime) / file.fileFormat.sampleRate)

    return currentTime
  }

  func seek(position: TimeInterval) {

    let sampleRate = file.fileFormat.sampleRate

    let startFrame = AVAudioFramePosition(sampleRate * position)
    let endFrame = AVAudioFramePosition(duration * sampleRate)
    let frameCount = AVAudioFrameCount(endFrame - startFrame)

    guard frameCount > 0 else {
      audioPlayer.stop()
      return
    }

    audioPlayer.stop()

    audioPlayer.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)

    audioPlayer.play()

  }

}

import AppService
import SwiftSubtitles
import AudioKit
import MediaPlayer

@MainActor
@Observable
public final class PlayerController: NSObject {

  public private(set) var playingRange: PlayingRange?

  public var isRepeating: Bool {
    playingRange != nil
  }

  public var isPlaying: Bool = false
  public var currentCue: DisplayCue?

  public let cues: [DisplayCue]
  private let subtitles: Subtitles

  @ObservationIgnored
  private var currentTimeObservation: NSKeyValueObservation?

  @ObservationIgnored
  private var currentTimer: Timer?

  @ObservationIgnored
  private var currentTimerForLoop: Timer?
  //  private let player: AVAudioPlayer

  @ObservationIgnored
  private let controller: AudioPlayerController

  let title: String

  public convenience init(item: Item) throws {
    try self.init(title: item.id, audioFileURL: item.audioFileURL, subtitleFileURL: item.subtitleFileURL)
  }

  public convenience init(item: ItemEntity) throws {

    try self.init(
      title: item.title,
      audioFileURL: item.audioFileRelativePath!.absolute(basedOn: AbsolutePath(url: URL.documentsDirectory)).url,
      subtitleFileURL: item.subtitleRelativePath!.absolute(basedOn: AbsolutePath(url: URL.documentsDirectory)).url
    )
  }

  public init(title: String, audioFileURL: URL, subtitleFileURL: URL) throws {

    self.subtitles = try Subtitles(fileURL: subtitleFileURL, encoding: .utf8)
    self.cues = subtitles.cues.map { .init(backed: $0) }
    self.title = title

    self.controller = try .init(file: .init(forReading: audioFileURL))
    super.init()
  }

  public func makeRepeatingRange() -> PlayingRange {
    .init(whole: cues)
  }

  @MainActor
  public func setRepeating(from pin: PinEntity) {

    var range = makeRepeatingRange()
    range.select(startCueID: pin.startCueRawIdentifier, endCueID: pin.endCueRawIdentifier)
    setRepeat(range: range)
  }

  public func setRepeating(identifier: String) {
    guard let cue = cues.first(where: { $0.id == identifier }) else { return }

    var range = makeRepeatingRange()
    range.select(cue: cue)
    setRepeat(range: range)
  }

  private func resetCommandCenter() {

    MPRemoteCommandCenter.shared().playCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(self)

    let commandCenter = MPRemoteCommandCenter.shared()

    //    commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(onTogglePlayPauseCommand))
    commandCenter.playCommand.addTarget(self, action: #selector(onPlayCommand))
    commandCenter.pauseCommand.addTarget(self, action: #selector(onPauseCommand))
    commandCenter.nextTrackCommand.addTarget(self, action: #selector(onNextTrackCommand))
    commandCenter.previousTrackCommand.addTarget(self, action: #selector(onPreviousTrackCommand))

  }

  @objc
  private dynamic func onTogglePlayPauseCommand() -> MPRemoteCommandHandlerStatus {
    if isPlaying {
      pause()
    } else {
      play()
    }
    return .success
  }

  @objc
  private dynamic func onPlayCommand() -> MPRemoteCommandHandlerStatus {
    self.play()
    return .success
  }

  @objc
  private dynamic func onPauseCommand() -> MPRemoteCommandHandlerStatus {
    self.pause()
    return .success
  }

  @objc
  private dynamic func onNextTrackCommand() -> MPRemoteCommandHandlerStatus {
    self.moveToNext()
    return .success
  }

  @objc
  private dynamic func onPreviousTrackCommand() -> MPRemoteCommandHandlerStatus {
    self.moveToPrevious()
    return .success
  }

  deinit {

    Log.debug("deinit \(self)")

    Task { [currentTimeObservation, currentTimer, currentTimerForLoop] in
      currentTimeObservation?.invalidate()
      currentTimer?.invalidate()
      currentTimerForLoop?.invalidate()
    }

    MPRemoteCommandCenter.shared().playCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(self)
  }

  public func play() {

    do {

      let instance = AVAudioSession.sharedInstance()
      try instance.setCategory(
        .playback,
        mode: .default,
        options: [.allowBluetooth, .allowAirPlay, .duckOthers]
      )
      try instance.setActive(true)

      try controller.play()
    } catch {

    }

    resetCommandCenter()

    isPlaying = true

    MPNowPlayingInfoCenter.default().playbackState = .playing

//    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in
//
//      MainActor.assumeIsolated { [weak self] in
//        guard let self else { return }
//
//        if let playingRange, playingRange.endTime < player.currentTime {
//          let diff = player.currentTime - playingRange.startTime
//          player.seek(time: -diff)
//        } else {
//          let c = self.findCurrentCue()
//          if self.currentCue != c {
//            self.currentCue = c
//          }
//        }
//      }
//
//    }
//
//    RunLoop.main.add(currentTimerForLoop!, forMode: .common)
//
//    currentTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
//
//      MainActor.assumeIsolated { [weak self] in
//        guard let self else { return }
//
//        do {
//          var nowPlayingInfo: [String: Any] = [:]
//
//          nowPlayingInfo[MPMediaItemPropertyTitle] = self.title
//          nowPlayingInfo[MPMediaItemPropertyArtist] = "Audio"
//          nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
//          nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
//          nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = timePitch.rate
//          nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
//
//          MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
//        }
//      }
//
//    }

  }

  public func pause() {

    isPlaying = false
    controller.pause()

    currentTimerForLoop?.invalidate()
    currentTimerForLoop = nil

    currentTimer?.invalidate()
    currentTimer = nil

  }

  public func move(to cue: DisplayCue) {

    if isPlaying == false {
      play()
    }

    controller.seek(position: cue.backed.startTime.timeInSeconds)

    self.currentCue = cue

  }

  public func moveToNext() {

    guard let currentCue else {
      return
    }

    guard let target = cues.nextElement(after: currentCue) else { return }

    if playingRange == nil {
      move(to: target)
    } else {
      // TODO: considier what to do
      //      setRepeat(in: target)
    }
  }

  public func moveToPrevious() {

    guard let currentCue else {
      return
    }

    guard let target = cues.previousElement(before: currentCue) else { return }

    if playingRange == nil {
      move(to: target)
    } else {
      // TODO: considier what to do
      //      setRepeat(in: target)
    }
  }

  public func setRepeat(range: PlayingRange?) {

    if let range {

      playingRange = range
      move(to: range.startCue)

    } else {

      playingRange = nil

    }
  }

  public func setRate(_ rate: Double) {
    controller.setSpeed(speed: rate)
  }
 
}

extension Array where Element: Equatable {

  fileprivate func nextElement(after: Element) -> Element? {
    guard let index = self.firstIndex(of: after), self.indices.contains(index + 1) else {
      return nil
    }
    return self[index + 1]
  }

  fileprivate func previousElement(before: Element) -> Element? {
    guard let index = self.firstIndex(of: before), self.indices.contains(index - 1) else {
      return nil
    }
    return self[index - 1]

  }

}
