import AVFoundation
import Foundation
import SwiftUI

struct HostTime: CustomDebugStringConvertible {

  let value: UInt64

  static var zero: HostTime {
    HostTime(value: 0)
  }

  /// 現在のhostTimeを取得
  static var now: HostTime {
    HostTime(value: mach_absolute_time())
  }

  /// 秒からhostTimeへ変換
  static func from(seconds: TimeInterval) -> HostTime {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let nanos = seconds * 1_000_000_000.0
    let hostTime = UInt64(nanos * Double(timebase.denom) / Double(timebase.numer))
    return HostTime(value: hostTime)
  }
  
  static func from(duration: Duration) -> HostTime {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)    
    let nanos = duration.components.seconds * 1_000_000_000 + Int64(duration.components.attoseconds / 1_000_000_000)    
    let hostTime = UInt64(nanos) * UInt64(timebase.denom) / UInt64(timebase.numer)    
    return HostTime(value: hostTime)
  }
  
  var duration: Duration {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let nanos = Double(value) * Double(timebase.numer) / Double(timebase.denom)
    return .nanoseconds(Int64(nanos))
  }

  /// hostTimeを秒に変換
  var seconds: TimeInterval {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let nanos = Double(value) * Double(timebase.numer) / Double(timebase.denom)
    return nanos / 1_000_000_000.0
  }

  /// AVAudioTimeへの変換
  var avAudioTime: AVAudioTime {
    AVAudioTime(hostTime: value)
  }

  func adding(by duration: Duration) -> HostTime {
    let seconds = duration.timeInterval
    let added = HostTime.from(seconds: seconds)
    return HostTime(
      value: self.value + added.value
    )
  }

  var debugDescription: String {
    self.seconds.description
  }
}

extension HostTime {

  static func + (lhs: HostTime, rhs: HostTime) -> HostTime {
    HostTime(value: lhs.value + rhs.value)
  }

  static func - (lhs: HostTime, rhs: HostTime) -> HostTime {
    HostTime(value: lhs.value - rhs.value)
  }

  /// HostTimeの差分をDurationで取得
  func durationSince(_ other: HostTime) -> Duration {
    let seconds = self.seconds - other.seconds
    return .seconds(seconds)
  }

  /// HostTimeの差分をTimeIntervalで取得
  func timeIntervalSince(_ other: HostTime) -> TimeInterval {
    self.seconds - other.seconds
  }
}

extension Duration {
  var timeInterval: TimeInterval {
    Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000.0
  }
}

@MainActor
final class AudioTimeline {

  @MainActor
  final class Track {

    enum Offset {
      case time(Duration)
    }

    var name: String
    let player: AVAudioPlayerNode
    let pitchControl: AVAudioUnitTimePitch = AVAudioUnitTimePitch()
    let file: AVAudioFile

    var offset: Offset?

    var duration: TimeInterval {
      Double(file.length) / file.processingFormat.sampleRate
    }

    private var pausedTime: AVAudioTime?
    
    private let clock: @MainActor () -> Clock

    init(
      name: String,
      file: AVAudioFile,
      offset: Offset?,
      clock: @escaping @MainActor () -> Clock
    ) {
      self.clock = clock
      self.name = name
      self.player = .init()
      self.file = file
      self.offset = offset
    }

    func pause() {
      player.stop()
    }

    func play() {
      player.play()
    }

    func set(rate: Float) {
      assert(rate >= (1 / 32) && rate <= 32)
      pitchControl.rate = rate
    }
    
    private var startedFrame: AVAudioFramePosition = 0
    
    func currentTime() -> TimeInterval? {
      guard let playerTime = player.playerTime else {
        return nil
      }
      return Double(startedFrame + playerTime.sampleTime) / playerTime.sampleRate
    }
    
    private func position(in wallTime: HostTime) -> Duration {
      let wallTime = wallTime
      let rate = pitchControl.rate
      let timeInAudio = wallTime.duration * Double(rate)   
      return timeInAudio
    }
        
    func seek(wallTime: HostTime) {
                  
      let timeInAudio = position(in: wallTime)
                  
      let adjustedSeconds = {
        switch self.offset {
        case .time(let offset):
          return timeInAudio - offset
        case .none:
          return timeInAudio
        }
      }()

      if adjustedSeconds < .zero {        
        
        let flipped = Duration.init(
          secondsComponent: -adjustedSeconds.components.seconds,
          attosecondsComponent: -adjustedSeconds.components.attoseconds
        )
                
        player.scheduleSegment(
          file,
          startingFrame: 0,
          frameCount: AVAudioFrameCount(file.length),
          at: .init(
            hostTime: (
              HostTime.now + HostTime.from(duration: flipped)
            ).value
          )
        )
        
        startedFrame = 0
      } else {

        let startSeconds = adjustedSeconds
        let startingFrame = max(
          0, AVAudioFramePosition(startSeconds.timeInterval * file.processingFormat.sampleRate)
        )
        
        let frameCount = max(0, AVAudioFrameCount(file.length - startingFrame))
        player.scheduleSegment(
          file,
          startingFrame: startingFrame,
          frameCount: frameCount,
          at: nil
        )
        
        startedFrame = startingFrame
      }

    }

    func add(to engine: AVAudioEngine) {
      engine.attach(player)
      engine.attach(pitchControl)
      engine.connect(player, to: pitchControl, format: file.processingFormat)
      engine.connect(pitchControl, to: engine.mainMixerNode, format: file.processingFormat)
    }
  }

  private var tracks: [Track] = []
  private var clock: Clock = .init()
  
  var currentWallTime: HostTime {
    clock.current
  }

  @discardableResult
  func addTrack(
    name: String,
    file: AVAudioFile,
    offset: Track.Offset? = nil
  ) -> Track {
    let track = Track(
      name: name,
      file: file,
      offset: offset,
      clock: { [unowned self] in
        self.clock
      }
    )
    tracks.append(track)
    return track
  }

  private func seek(wallTime: HostTime) {
    for track in tracks {
      track.seek(wallTime: wallTime)
    }
  }

  func seek(position: TimeInterval) {
    if clock.isRunning {      
      self.pause()
      self.playAll(at: position)
    } else {
      self.seek(wallTime: HostTime.from(seconds: position))
    }
  }

  func playAll(at position: TimeInterval? = nil) {
    
    clock.start()

    if let position = position {
      clock.seek(offset: .from(seconds: position))
    }

    seek(wallTime: clock.current)

    for track in tracks {
      track.play()
    }    
  }

  func pause() {

    clock.pause()

    for track in tracks {
      track.pause()
    }
  }

  func stop() {
    clock.pause()
    clock.seek(offset: .zero)
    for track in tracks {
      track.player.stop()
    }
  }

  func attach(to engine: AVAudioEngine) {
    for track in tracks {
      track.add(to: engine)
    }
  }

  func debug() {

    print(clock.current)

  }

}

extension AVAudioPlayerNode {
  var playerTime: AVAudioTime? {

    guard let nodeTime = self.lastRenderTime else {
      return nil
    }

    return self.playerTime(forNodeTime: nodeTime)
  }
}

@MainActor
private final class Controller: ObservableObject {

  let timeline: AudioTimeline = .init()
  let engine: AVAudioEngine = .init()

  var isPrepared: Bool = false

  func stop() {
    timeline.pause()
  }

  func start() {
    if !isPrepared {
      prepare()
      isPrepared = true
    }
    timeline.playAll()
  }

  func prepare() {
    do {
      try AudioSessionManager.shared.activate()

      let aTrack = timeline.addTrack(
        name: "A",
        file: .test1(),
        offset: nil
      )

      aTrack.set(rate: 0.5)

      timeline.addTrack(
        name: "B",
        file: .test2(),
        offset: .time(.seconds(5))
      )

      timeline.attach(to: engine)

      try engine.start()

      //      timeline.seek(position: 0)
    } catch {
      assertionFailure()
    }
  }

}

struct TimelineWrapper: View {

  @StateObject private var object = Controller()
  @State private var isPlaying = false

  var body: some View {
    VStack {
      Button("Play") {
        if isPlaying {
          object.stop()
        } else {
          object.start()
        }
        isPlaying.toggle()
      }
    }
  }

}

extension AVAudioFile {

  static func test1() -> AVAudioFile {
    let url = Bundle.main.url(
      forResource: "Social Media Has Ruined Photography", withExtension: "mp3")!
    return try! AVAudioFile(forReading: url)
  }

  static func test2() -> AVAudioFile {
    let url = Bundle.main.url(forResource: "overwhelmed - Peter Mckinnon", withExtension: "mp3")!
    return try! AVAudioFile(forReading: url)
  }
}

struct Clock {

  private(set) var isRunning: Bool = false

  private var elapsed: HostTime {
    let elapsedTime = HostTime.now - started
    return elapsedTime
  }

  private(set) var started: HostTime = .now
  private(set) var offset: HostTime = .zero

  var current: HostTime {
    if isRunning {
      let elapsedTime = HostTime.now - started
      return offset + elapsedTime
    } else {
      return offset
    }
  }

  init() {

  }

  mutating func seek(offset: HostTime) {
    self.offset = offset
  }

  mutating func start() {
    self.isRunning = true
    self.started = .now
  }

  mutating func pause() {
    self.isRunning = false
    offset = offset + elapsed
  }
}

#Preview {

  struct ClockView: View {

    @State var clock = Clock()
    @State var isPlaying = false

    var body: some View {
      Button("Hit") {
        if isPlaying {
          clock.pause()
        } else {
          clock.start()
        }
        isPlaying.toggle()
        print(clock.offset.seconds)
      }
      Button("Seek 5") {
        clock.seek(offset: .from(seconds: 5))
      }
      Text("IsPlaying: \(isPlaying.description)")
        .padding()

      Text("Elapsed: \(clock.offset.seconds)")
        .padding()

      TimelineView(.animation) { _ in
        Text("Current: \(clock.current.seconds)")
          .padding()
      }
    }
  }

  return ClockView()

}

#Preview {

  return TimelineWrapper()
}
