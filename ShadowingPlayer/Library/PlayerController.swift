import AppService
import MediaPlayer
import SwiftSubtitles
import Verge

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

  private var cancellables: Set<AnyCancellable> = .init()

  public convenience init(item: Item) throws {
    try self.init(
      title: item.id,
      audioFileURL: item.audioFileURL,
      subtitleFileURL: item.subtitleFileURL
    )
  }

  public convenience init(item: ItemEntity) throws {

    try self.init(
      title: item.title,
      audioFileURL: item.audioFileRelativePath!.absolute(
        basedOn: AbsolutePath(url: URL.documentsDirectory)
      ).url,
      subtitleFileURL: item.subtitleRelativePath!.absolute(
        basedOn: AbsolutePath(url: URL.documentsDirectory)
      ).url
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

    Task { @MainActor [currentTimeObservation, currentTimer, currentTimerForLoop] in
      currentTimeObservation?.invalidate()
      currentTimer?.invalidate()
      currentTimerForLoop?.invalidate()
    }

    MPRemoteCommandCenter.shared().playCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(self)
    MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(self)
  }

  func activate() {
    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(true)
      try instance.setCategory(
        .playback,
        mode: .default,
        options: [.allowBluetooth, .allowAirPlay, .mixWithOthers]
      )
    } catch {
      print(error)
    }

  }

  func deactivate() {

    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(false)
    } catch {
      print(error)
    }
  }

  public func play() {

    do {
      try controller.play()
    } catch {

      Log.error("\(error.localizedDescription)")

    }

    resetCommandCenter()

    isPlaying = true

    MPNowPlayingInfoCenter.default().playbackState = .playing

    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] in
        guard let self else { return }

        if let currentTime = controller.currentTime {
          
          let currentCue = cues.first { cue in
            
            (cue.backed.startTime..<cue.backed.endTime).contains(currentTime)
            
          }
          
          if self.currentCue != currentCue {
            self.currentCue = currentCue
          }
        }

      }

    }

    RunLoop.main.add(currentTimerForLoop!, forMode: .common)
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
    
    controller.seek(position: cue.backed.startTime)

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
      controller.repeating = .range(start: range.startTime, end: range.endTime)

    } else {

      playingRange = nil
      controller.repeating = nil

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
