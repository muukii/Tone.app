import AudioKit
import MediaPlayer
import SwiftSubtitles
import Observation

struct DisplayCue: Identifiable, Equatable {

  let id: String

  let backed: Subtitles.Cue

  init(backed: Subtitles.Cue) {
    self.backed = backed
    let s = backed.startTime
    self.id = "\(s.hour),\(s.minute),\(s.second),\(s.millisecond)"

  }
}

@Observable
final class PlayerController: NSObject {

  struct PlayingRange: Equatable {

    var startTime: TimeInterval { startCue.backed.startTime.timeInSeconds }
    var endTime: TimeInterval { endCue.backed.endTime.timeInSeconds }

    var startCue: DisplayCue
    var endCue: DisplayCue
  
    init(startCue: DisplayCue, endCue: DisplayCue) {
      self.startCue = startCue
      self.endCue = endCue
    }

    func contains(_ cue: DisplayCue) -> Bool {
      cue.backed.startTime >= startCue.backed.startTime
        && cue.backed.endTime <= endCue.backed.endTime    
    }

    func isExact(with cue: DisplayCue) -> Bool {
      startCue == cue && endCue == cue
    }
  }

  private(set) var playingRange: PlayingRange?

  var isRepeating: Bool {
    playingRange != nil
  }

  var isPlaying: Bool = false
  var currentCue: DisplayCue?

  let cues: [DisplayCue]
  private let subtitles: Subtitles

  private var currentTimeObservation: NSKeyValueObservation?
  private var currentTimer: Timer?
  //  private let player: AVAudioPlayer

  let title: String
  let engine = AudioEngine()
  let player: AudioPlayer
  let timePitch: TimePitch

  convenience init(item: Item) throws {
    try self.init(title: item.id, audioFileURL: item.audioFileURL, subtitleFileURL: item.subtitleFileURL)
  }

  convenience init(item: ItemEntity) throws {

    try self.init(
      title: item.title!,
      audioFileURL: item.audioFileRelativePath!.absolute(basedOn: AbsolutePath(url: URL.documentsDirectory)).url,
      subtitleFileURL: item.subtitleRelativePath!.absolute(basedOn: AbsolutePath(url: URL.documentsDirectory)).url
    )
  }

  init(title: String, audioFileURL: URL, subtitleFileURL: URL) throws {

    player = .init(url: audioFileURL, buffered: false)!

    timePitch = .init(player)
    timePitch.rate = 1.0

    engine.output = timePitch

    self.subtitles = try Subtitles(fileURL: subtitleFileURL, encoding: .utf8)
    self.cues = subtitles.cues.map { .init(backed: $0) }
    self.title = title

    super.init()
  }

  func setRepeating(identifier: String) {
    guard let cue = cues.first(where: { $0.id == identifier }) else { return }
    setRepeat(range: .init(startCue: cue, endCue: cue))
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

    print("deinit")
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

        nowPlayingInfo[MPMediaItemPropertyTitle] = title
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

    let diff = player.currentTime - cue.backed.startTime.timeInSeconds

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
      // TODO: considier what to do
//      setRepeat(in: target)
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
      // TODO: considier what to do
//      setRepeat(in: target)
    }
  }

  func setRepeat(range: PlayingRange?) {

    if let range {

      playingRange = range
      move(to: range.startCue)

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

      (cue.backed.startTime.timeInSeconds..<cue.backed.endTime.timeInSeconds).contains(currentTime)

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
