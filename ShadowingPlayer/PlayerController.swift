import AudioKit
import MediaPlayer
import SwiftSubtitles

struct DisplayCue: Identifiable, Equatable {

  let id: String

  let backed: Subtitles.Cue

  init(backed: Subtitles.Cue) {
    self.backed = backed
    let s = backed.startTime
    self.id = "\(s.hour),\(s.minute),\(s.second),\(s.millisecond)"

  }
}

@MainActor
final class PlayerController: NSObject, ObservableObject {

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
  //  private let player: AVAudioPlayer

  let engine = AudioEngine()
  let player: AudioPlayer
  let timePitch: TimePitch

  init(item: Item) throws {
    self.item = item

    player = .init(url: item.audioFileURL, buffered: false)!

    timePitch = .init(player)
    timePitch.rate = 1.0

    engine.output = timePitch

    self.subtitles = try Subtitles(fileURL: item.subtitleFileURL, encoding: .utf8)
    self.cues = subtitles.cues.map { .init(backed: $0) }

    super.init()

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
    currentTimeObservation?.invalidate()

    MPRemoteCommandCenter.shared().playCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(self)
  }

  func play() {

    do {

      try engine.start()

      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(true, options: .notifyOthersOnDeactivation)
      try instance.setCategory(
        .playback,
        mode: .default,
        options: [.allowBluetooth, .allowAirPlay]
      )

    } catch {

    }

    resetCommandCenter()

    isPlaying = true

    player.play()

    MPNowPlayingInfoCenter.default().playbackState = .playing

    currentTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) {
      @MainActor(unsafe) [weak self] _ in

      guard let self else { return }
      let c = self.findCurrentCue()
      if self.currentCue != c {
        self.currentCue = c
      }

      if let playingRange, playingRange.endTime < player.currentTime {
        let diff = player.currentTime - playingRange.startTime
        player.seek(time: -diff)
      }

      do {
        var nowPlayingInfo: [String: Any] = [:]

        nowPlayingInfo[MPMediaItemPropertyTitle] = item.id
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Audio"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = timePitch.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      }

    }

  }

  func pause() {

    isPlaying = false
    player.pause()

    currentTimer?.invalidate()
    currentTimer = nil

    engine.pause()

  }

  func move(to cue: DisplayCue) {

    if isPlaying == false {
      play()
    }

    let diff = player.currentTime - cue.backed.startTime.timeInterval

    player.seek(time: -diff)

    self.currentCue = cue

  }

  func moveToNext() {

    guard let currentCue else {
      return
    }

    guard let target = cues.nextElement(after: currentCue) else { return }

    if playingRange == nil {
      move(to: target)
    } else {
      setRepeat(in: target)
    }
  }

  func moveToPrevious() {

    guard let currentCue else {
      return
    }

    guard let target = cues.previousElement(before: currentCue) else { return }

    if playingRange == nil {
      move(to: target)
    } else {
      setRepeat(in: target)
    }
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
    timePitch.rate = rate
  }

  func findCurrentCue() -> DisplayCue? {

    let currentTime = player.currentTime

    let currentCue = cues.first { cue in

      (cue.backed.startTime.timeInterval..<cue.backed.endTime.timeInterval).contains(currentTime)

    }

    return currentCue
  }
}

extension Array where Element: Equatable {

  func nextElement(after: Element) -> Element? {
    guard let index = self.firstIndex(of: after), self.indices.contains(index + 1) else {
      return nil
    }
    return self[index + 1]
  }

  func previousElement(before: Element) -> Element? {
    guard let index = self.firstIndex(of: before), self.indices.contains(index - 1) else {
      return nil
    }
    return self[index - 1]

  }

}
