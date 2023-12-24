import AudioKit
import MediaPlayer
import SwiftSubtitles
import Observation

public struct DisplayCue: Identifiable, Hashable {

  public func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
  }

  public let id: String

  public let backed: Subtitles.Cue

  public init(backed: Subtitles.Cue) {
    self.backed = backed
    let s = backed.startTime
    self.id = "\(s.hour),\(s.minute),\(s.second),\(s.millisecond)"

  }
}

@Observable
public final class PlayerController: NSObject {

  public struct PlayingRange: Equatable {

    private var whole: [DisplayCue]

    public var startTime: TimeInterval {
      cues.first?.backed.startTime.timeInSeconds ?? whole.first?.backed.startTime.timeInSeconds ?? 0
    }
    public var endTime: TimeInterval {
      cues.last?.backed.endTime.timeInSeconds ?? whole.last?.backed.endTime.timeInSeconds ?? 0
    }

    public var startCue: DisplayCue {
      cues.first!
    }

    public var endCue: DisplayCue {
      cues.last!
    }

    private var cues: [DisplayCue] = []

    init(
      whole: [DisplayCue]
    ) {
      self.whole = whole
    }

    public func contains(_ cue: DisplayCue) -> Bool {
      cue.backed.startTime.timeInSeconds >= startTime && cue.backed.endTime.timeInSeconds <= endTime
    }

    public mutating func select(startCueID: String, endCueID: String) {

      let startCue = whole.first { $0.id == startCueID }!
      let endCue = whole.first { $0.id == endCueID }!

      let startTime = min(startCue.backed.startTime.timeInSeconds, endCue.backed.startTime.timeInSeconds)
      let endTime = max(startCue.backed.endTime.timeInSeconds, endCue.backed.endTime.timeInSeconds)

      cues = whole.filter {
        $0.backed.startTime.timeInSeconds >= startTime && $0.backed.endTime.timeInSeconds <= endTime
      }

    }

    public mutating func select(cue: DisplayCue) {

      if cues.isEmpty {
        cues = [cue]
        return
      }

      if cues.contains(cue) {

        let count = cues.count
        let i = cues.firstIndex(of: cue)!

        if count / 2 < i {
          cues = Array(cues[...i])
        } else {
          cues = Array(cues[(i)...])
        }

      } else {

        let startTime = min(self.startTime, cue.backed.startTime.timeInSeconds)
        let endTime = max(self.endTime, cue.backed.endTime.timeInSeconds)

        cues = whole.filter {
          $0.backed.startTime.timeInSeconds >= startTime && $0.backed.endTime.timeInSeconds <= endTime
        }

      }

    }

//    mutating func add(cue: DisplayCue) {
//      guard cues.contains(cue) == false else { return }
//      cues.append(cue)
//      cues.sort { $0.backed.startTime < $1.backed.startTime }
//    }
//
//    mutating func remove(cue: DisplayCue) {
//      cues.removeAll { $0 == cue }
//    }
  }

  public private(set) var playingRange: PlayingRange?

  public var isRepeating: Bool {
    playingRange != nil
  }

  public var isPlaying: Bool = false
  public var currentCue: DisplayCue?

  public let cues: [DisplayCue]
  private let subtitles: Subtitles

  private var currentTimeObservation: NSKeyValueObservation?

  private var currentTimer: Timer?
  private var currentTimerForLoop: Timer?
  //  private let player: AVAudioPlayer

  let title: String
  let engine = AudioEngine()
  let player: AudioPlayer
  let timePitch: TimePitch

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

    player = .init(url: audioFileURL, buffered: false)!

    timePitch = .init(player)
    timePitch.rate = 1.0

    engine.output = timePitch

    self.subtitles = try Subtitles(fileURL: subtitleFileURL, encoding: .utf8)
    self.cues = subtitles.cues.map { .init(backed: $0) }
    self.title = title

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

    currentTimeObservation?.invalidate()
    currentTimer?.invalidate()
    currentTimerForLoop?.invalidate()

    MPRemoteCommandCenter.shared().playCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(self)
  }

  public func play() {

    do {

      try engine.start()

      let instance = AVAudioSession.sharedInstance()
      try instance.setCategory(
        .playback,
        mode: .default,
        options: [.allowBluetooth, .allowAirPlay, .mixWithOthers]
      )
      try instance.setActive(true)

    } catch {

    }

    resetCommandCenter()

    isPlaying = true

    player.play()

    MPNowPlayingInfoCenter.default().playbackState = .playing

    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] in
        guard let self else { return }

        if let playingRange, playingRange.endTime < player.currentTime {
          let diff = player.currentTime - playingRange.startTime
          player.seek(time: -diff)
        } else {
          let c = self.findCurrentCue()
          if self.currentCue != c {
            self.currentCue = c
          }
        }
      }

    }

    RunLoop.main.add(currentTimerForLoop!, forMode: .common)

    currentTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] in
        guard let self else { return }

        do {
          var nowPlayingInfo: [String: Any] = [:]

          nowPlayingInfo[MPMediaItemPropertyTitle] = self.title
          nowPlayingInfo[MPMediaItemPropertyArtist] = "Audio"
          nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
          nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
          nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = timePitch.rate
          nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

          MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
      }

    }

  }

  public func pause() {

    isPlaying = false
    player.pause()

    currentTimerForLoop?.invalidate()
    currentTimerForLoop = nil

    currentTimer?.invalidate()
    currentTimer = nil

    engine.pause()

  }

  public func move(to cue: DisplayCue) {

    if isPlaying == false {
      play()
    }

    let diff = player.currentTime - cue.backed.startTime.timeInSeconds

    player.seek(time: -diff)

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

  public func setRate(_ rate: Float) {
    timePitch.rate = rate
  }

  public func findCurrentCue() -> DisplayCue? {

    let currentTime = player.currentTime

    let currentCue = cues.first { cue in

      (cue.backed.startTime.timeInSeconds..<cue.backed.endTime.timeInSeconds).contains(currentTime)

    }

    return currentCue
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
