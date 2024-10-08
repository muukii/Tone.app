import AppService
import MediaPlayer
import SwiftSubtitles
import Verge
import Observation

@MainActor
@Observable
public final class PlayerController: NSObject {

  public private(set) var playingRange: PlayingRange?

  public var isRepeating: Bool {
    playingRange != nil
  }

  public private(set) var isPlaying: Bool = false

  public private(set) var currentCue: DisplayCue?

  public let cues: [DisplayCue]

  public var pin: [PinEntity] = []

  @ObservationIgnored
  private var currentTimeObservation: NSKeyValueObservation?

  @ObservationIgnored
  private var currentTimer: Timer?

  @ObservationIgnored
  private var currentTimerForLoop: Timer?
  //  private let player: AVAudioPlayer

  @ObservationIgnored
  private let controller: AudioPlayerController

  let audioFileURL: URL

  let title: String

  @ObservationIgnored
  private var isActivated: Bool = false

  @ObservationIgnored
  private var cancellables: Set<AnyCancellable> = .init()

  @ObservationIgnored
  private var isAppInBackground: Bool = false

  public convenience init(item: Item) throws {
    try self.init(
      title: item.id,
      audioFileURL: item.audioFileURL,
      subtitleFileURL: item.subtitleFileURL
    )
  }

  public convenience init(item: ItemEntity) throws {

    let segment = try item.segment()

    try self.init(
      title: item.title,
      audioFileURL: item.audioFileAbsoluteURL,
      segments: segment.items
    )
  }

  public convenience init(title: String, audioFileURL: URL, subtitleFileURL: URL) throws {

    let subtitles = try Subtitles(fileURL: subtitleFileURL, encoding: .utf8)

    try self.init(title: title, audioFileURL: audioFileURL, segments: subtitles.cues.map { AbstractSegment(cue: $0) })
  }

  public init(title: String, audioFileURL: URL, segments: [AbstractSegment]) throws {

    self.cues = segments.enumerated().map { i, e in .init(segment: e, index: i) }
    self.title = title
    self.audioFileURL = audioFileURL

    self.controller = try .init(file: .init(forReading: audioFileURL))
    self.controller.repeating = .atEnd
    super.init()

    controller.sinkState { [weak self] state in

      guard let self else { return }

      state.ifChanged(\.isPlaying).do {
        self.isPlaying = $0
      }

    }
    .store(in: &cancellables)

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
      
      Log.debug("deinit \(self)")
      
      do {
        let instance = AVAudioSession.sharedInstance()
        try instance.setActive(false, options: .notifyOthersOnDeactivation)
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
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(true, options: .notifyOthersOnDeactivation)
      try instance.setCategory(
        .playback,
        mode: .default,
        policy: .default,
        options: []
      )
    } catch {
      print(error)
    }

  }

  func deactivate() {

    guard isActivated == true else {
      return
    }

    isActivated = false

    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print(error)
    }
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
      controller.seek(position: range.startTime)

    } else {

      playingRange = nil
      controller.repeating = .atEnd

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
