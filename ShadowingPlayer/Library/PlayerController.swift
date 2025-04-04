import AppService
import MediaPlayer
import SwiftSubtitles
import Verge

@MainActor
public final class PlayerController: NSObject, StoreDriverType {
  
  @Tracking
  public struct State {
            
    public let title: String
    
    public let audioFileURL: URL    
    
    public var playingRange: PlayingRange?
    
    public var isRepeating: Bool {
      playingRange != nil
    }
    
    public var isPlaying: Bool
    
    public var currentCue: DisplayCue?
    
    public let cues: [DisplayCue]
    
    public var pin: [PinEntity] = []
    
    public init(
      title: String,
      audioFileURL: URL,
      playingRange: PlayingRange? = nil,
      isPlaying: Bool = false,
      currentCue: DisplayCue? = nil,
      cues: [DisplayCue] = [],
      pin: [PinEntity] = []
    ) {
      self.title = title
      self.audioFileURL = audioFileURL
      self.playingRange = playingRange
      self.isPlaying = isPlaying
      self.currentCue = currentCue
      self.cues = cues
      self.pin = pin
    }
      
  }
  
//  nonisolated public static func == (lhs: PlayerController, rhs: PlayerController) -> Bool {
//    lhs === rhs
//  }
//  
//  public nonisolated func hash(into hasher: inout Hasher) {
//    hasher.combine(ObjectIdentifier(self))
//  }
  
  public let store: Store<State, Never>

  private var currentTimeObservation: NSKeyValueObservation?
  
  private var currentTimer: Timer?

  private var currentTimerForLoop: Timer?
  //  private let player: AVAudioPlayer

  private let controller: AudioPlayerController

  private var isActivated: Bool = false

  private var cancellables: Set<AnyCancellable> = .init()

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
    
    self.store = .init(
      initialState: .init(
        title: title,
        audioFileURL: audioFileURL,
        cues: segments.enumerated()
          .map { i, e in .init(segment: e, index: i) }        
      )
    )
    
    self.controller = try .init(file: .init(forReading: audioFileURL))
    
    self.controller.repeating = .atEnd
    
    super.init()
    
    controller.sinkState { [weak self] state in

      guard let self else { return }

      state.ifChanged(\.isPlaying).do { isPlaying in
        self.commit { 
          $0.isPlaying = isPlaying
        }
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
    .init(whole: state.cues)
  }

  @MainActor
  public func setRepeating(from pin: PinEntity) {

    var range = makeRepeatingRange()
    range.select(startCueID: pin.startCueRawIdentifier, endCueID: pin.endCueRawIdentifier)
    setRepeat(range: range)
  }

  public func setRepeating(identifier: String) {
    guard let cue = state.cues.first(where: { $0.id == identifier }) else { return }

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
    if state.isPlaying {
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
          
          let currentCue = self.state.cues.first { cue in

            if cue.backed.startTime <= currentTime, cue.backed.endTime >= currentTime {
              return true
            } else {
              return false
            }

          }
          
          self.commit {
            if $0.currentCue != currentCue {
              $0.currentCue = currentCue
            }
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

    commit {
      $0.currentCue = cue
    }
    
  }

  public func moveToNext() {

    guard let currentCue = state.currentCue else {
      return
    }

    guard let target = state.cues.nextElement(after: currentCue) else { return }

    if state.playingRange == nil {
      move(to: target)
    } else {
      // TODO: considier what to do
      //      setRepeat(in: target)
    }
  }

  public func moveToPrevious() {

    guard let currentCue = state.currentCue else {
      return
    }

    guard let target = state.cues.previousElement(before: currentCue) else { return }

    if state.playingRange == nil {
      move(to: target)
    } else {
      // TODO: considier what to do
      //      setRepeat(in: target)
    }
  }

  public func setRepeat(range: PlayingRange?) {
    
    commit {
      
      if let range {
        
        $0.playingRange = range
        controller.repeating = .range(start: range.startTime, end: range.endTime)
        controller.seek(position: range.startTime)
        
      } else {
        
        $0.playingRange = nil
        controller.repeating = .atEnd
        
      }
      
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
