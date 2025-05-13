import AppService
import MediaPlayer
import StateGraph
import SwiftSubtitles

@MainActor
public final class PlayerController: NSObject {

  public let title: String

  public let audioFileURL: URL

  @GraphStored
  public var playingRange: PlayingRange?

  public var isRepeating: Bool {
    playingRange != nil
  }

  @GraphStored
  public var isPlaying: Bool = false

  @GraphStored
  public var rate: CGFloat = 1

  @GraphStored
  public var currentCue: DisplayCue?

  public let cues: [DisplayCue]

  @GraphStored
  public var pin: [PinEntity] = []

  private var currentTimeObservation: NSKeyValueObservation?

  private var currentTimer: Timer?

  private var currentTimerForLoop: Timer?

  private let controller: AudioPlayerController

  private var isActivated: Bool = false

  private var isAppInBackground: Bool = false

  public enum Source: Equatable {
    case item(Item)
    case entity(ItemEntity)
  }

  let source: Source

  public convenience init(item: Item) throws {

    let subtitles = try Subtitles(fileURL: item.subtitleFileURL, encoding: .utf8)

    try self.init(
      source: .item(item),
      title: item.id,
      audioFileURL: item.audioFileURL,
      segments: subtitles.cues.map { AbstractSegment(cue: $0) }
    )

  }

  public convenience init(item: ItemEntity) throws {

    let segment = try item.segment()

    try self.init(
      source: .entity(item),
      title: item.title,
      audioFileURL: item.audioFileAbsoluteURL,
      segments: segment.items
    )
  }

  public init(
    source: Source,
    title: String,
    audioFileURL: URL,
    segments: [AbstractSegment]
  ) throws {

    self.source = source

    self.title = title
    self.audioFileURL = audioFileURL
    self.cues = segments.enumerated()
      .map { i, e in .init(segment: e, index: i) }

    self.controller = try .init(file: .init(forReading: audioFileURL))

    self.controller.repeating = .atEnd

    super.init()

    withContinuousStateGraphTracking { [weak self] in
      _ = self?.rate
    } didChange: { [weak self] in
      guard let self else { return .stop }
      self.controller.setSpeed(speed: self.rate)
      return .next
    }

    withContinuousStateGraphTracking { [controller] in
      _ = controller.isPlaying
    } didChange: { [weak self] in
      guard let self else { return .stop }
      self.isPlaying = self.controller.isPlaying
      return .next
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

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
    MainActor.assumeIsolated {
      NotificationCenter.default.removeObserver(self)

      Log.debug("deinit \(String(describing: self))")

      do {
        try AudioSessionManager.shared.deactivate()
      } catch {
        print(error)
      }

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
  }

  func activate() {
    guard isActivated == false else {
      return
    }

    isActivated = true

    do {
      try AudioSessionManager.shared.activate()
    } catch {
      print(error)
    }
  }

  func deactivate() {
    guard isActivated == true else {
      return
    }

    isActivated = false
  }

  public func play() {

    if isActivated == false {
      activate()
    }

    do {
      try controller.play()
    } catch {

      Log.error("\(error.localizedDescription)")

    }

    resetCommandCenter()

    MPNowPlayingInfoCenter.default().playbackState = .playing

    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] in
        guard let self else { return }

        guard self.isAppInBackground == false else { return }

        if let currentTime = self.controller.currentTime {

          let currentCue = self.cues.first { cue in

            if cue.backed.startTime <= currentTime, cue.backed.endTime >= currentTime {
              return true
            } else {
              return false
            }

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

  @objc
  private func didEnterBackground() {
    isAppInBackground = true
  }

  @objc
  private func didBecomeActive() {
    isAppInBackground = false
  }

  public func pause() {

    guard isPlaying else {
      return
    }

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

    guard let currentCue = currentCue else {
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

    guard let currentCue = currentCue else {
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

      self.playingRange = range
      controller.repeating = .range(start: range.startTime, end: range.endTime)
      controller.seek(position: range.startTime)

    } else {

      self.playingRange = nil
      controller.repeating = .atEnd

    }

  }

  public func setRate(_ rate: CGFloat) {

    self.rate = rate

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
