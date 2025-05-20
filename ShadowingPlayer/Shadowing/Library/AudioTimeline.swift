import AVFoundation
import Foundation

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


final class AudioTimeline {
  

  
  final class Track {
    
    enum Offset {
      case time(TimeInterval)
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
    
    init(
      name: String,
      file: AVAudioFile,
      offset: Offset?
    ) {
      self.name = name
      self.player = .init()
      self.file = file
      self.offset = offset
    }
    
    func pause() {     
      self.pausedTime = playerTime
      player.stop()
    }
    
    func play() {                  
      player.play()
    }
    
    func set(rate: Float) {
      assert(rate >= (1 / 32) && rate <= 32)
      pitchControl.rate = rate
    }
    
    var playerTime: AVAudioTime? {
      guard let nodeTime = player.lastRenderTime else {
        return nil
      }
      
      guard let playerTime = player.playerTime(forNodeTime: nodeTime) else {
        return nil
      }
      
      return playerTime
    }
    
    func seek(wallTime: HostTime) {
      
      let rate = pitchControl.rate

      let seconds = wallTime.seconds * Double(rate)
      
      let adjustedSeconds = {
        switch self.offset {
        case .time(let offset):
          return seconds - offset
        case .none:
          return seconds
        }
      }()
      
      if adjustedSeconds < 0 {
       
      } else {
        // 即時再生: 途中から再生
        let startSeconds = abs(adjustedSeconds * Double(rate))
        let startingFrame = max(0, AVAudioFramePosition(startSeconds * file.processingFormat.sampleRate))
        let frameCount = max(0, AVAudioFrameCount(file.length - startingFrame))
        player.scheduleSegment(
          file,
          startingFrame: startingFrame,
          frameCount: frameCount,
          at: nil
        )
      }
      
//      if adjustedOffset > 0 {
//        // 遅延再生: 指定時刻から再生
//        let frameCount = AVAudioFrameCount(file.length)
//        let timing = AVAudioTime(
//          sampleTime: AVAudioFramePosition(adjustedOffset * file.processingFormat.sampleRate),
//          atRate: file.processingFormat.sampleRate
//        )
//        player.scheduleSegment(
//          file,
//          startingFrame: 0,
//          frameCount: frameCount,
//          at: timing
//        )
//      } else {
//        
//      }
    }
    
    func add(to engine: AVAudioEngine) {
      engine.attach(player)
      engine.attach(pitchControl)
      engine.connect(player, to: pitchControl, format: file.processingFormat)
      engine.connect(pitchControl, to: engine.mainMixerNode, format: file.processingFormat)
    }
  }
  
  private var tracks: [Track] = []
  
  @discardableResult
  func addTrack(
    name: String,
    file: AVAudioFile,
    offset: Track.Offset? = nil
  ) -> Track {
    let track = Track(
      name: name,
      file: file,
      offset: offset
    )
    tracks.append(track)
    return track
  }
  
  var totalDuration: TimeInterval {
    var duration: TimeInterval = 0
    for player in tracks {
      duration = max(player.duration, duration)
    }
    return duration
  }
  
  private var masterTrack: Track {
    assert(tracks.count > 0, "No tracks available")
    return tracks.filter {
      $0.offset == nil
    }
    .first!
  }
  
  var pausedRenderTime: AVAudioFramePosition = 0
  
  func seek(wallTime: HostTime) {
    for track in tracks {
      track.seek(wallTime: wallTime)
    }    
  }
  
  /*
  func seek(position: TimeInterval) {
    
    let masterTrack = self.masterTrack
    
    for track in tracks {
      
      
      if position < track.duration {
        
        if track === masterTrack {
          // record the paused point
          pausedRenderTime = track.file.frame(at: position)          
        }
        
        // Calculate the offset in time
        let _offset = {
          switch track.offset {
          case .time(let offset):
            return offset - position
          case .none:
            return 0
          }
        }()
        
        // For tracks that start after the current position
        if _offset > 0 {
          // Schedule from beginning of the track
          let frameCount = AVAudioFrameCount(track.file.length)
          
          // Create timing for delayed start
          let timing = AVAudioTime(
            sampleTime: AVAudioFramePosition(_offset * track.file.processingFormat.sampleRate),
            atRate: track.file.processingFormat.sampleRate
          )
          
          track.player.scheduleSegment(
            track.file,
            startingFrame: 0,
            frameCount: frameCount,
            at: timing
          )
        } else {
                    
          let frame = {
            switch track.offset {
            case .time(let offset):
              return track.file.frame(at: position + offset)
            case .none:
              return track.file.frame(at: position)
            }
          }()
          
          // For tracks that have already started or start at the current position
          let startingFrame = frame
          let frameCount = AVAudioFrameCount(track.file.length - startingFrame)
          
          // Immediate playback with no delay
          track.player.scheduleSegment(
            track.file,
            startingFrame: startingFrame,
            frameCount: frameCount,
            at: nil
          )
        }
      }
    }
  }
  */
  
  func playAll(at position: TimeInterval? = nil) {
    
    seek(wallTime: pausedWallTime)
        
    startedWallTime = .now        
    
//    if let position = position {
//      seek(position: position)
//    } else {
//      if let pausedTime {
//        seek(position: pausedTime)
//      }
//    }
    
    for track in tracks {
      track.play()
    }
  }
  
  func pause() {
    
    let time = masterTrack.playerTime?.sampleTime
    assert(time != nil)
    
//    self.pausedTime = currentTimeInMasterTrack    
    self.pausedWallTime = wallTime
    self.elapsedWallTime = .now - startedWallTime
    //    pausedRenderTime = (time ?? 0) + (pausedRenderTime)
    
    print("Paused", self.pausedWallTime.seconds, self.elapsedWallTime.seconds)
    
    for track in tracks {
      track.pause()
    }    
  }
  
  func stop() {
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
    
    print(currentTimeInMasterTrack, wallTime)
    
  }
  
  private var startedWallTime: HostTime = .now
  private var pausedWallTime: HostTime = .now
  private var elapsedWallTime: HostTime = .from(seconds: 0)
  private var pausedTime: TimeInterval?
  
  
  var wallTime: HostTime {
    let elapsedTime = HostTime.now - startedWallTime    
    return elapsedTime
  }
  
  var currentTimeInMasterTrack: TimeInterval? {
    
    guard let payerTime = masterTrack.playerTime else {
      return nil
    }
    
    let currentTime =
    (Double(payerTime.sampleTime + pausedRenderTime) / payerTime.sampleRate)
    
    return currentTime
    
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

import SwiftUI

@MainActor
private final class Controller: ObservableObject {
  
  let timeline: AudioTimeline = .init()
  let engine: AVAudioEngine = .init()
  
  var isPrepared: Bool = false
  var timer: Timer?
  
  func stop() {
    timeline.pause()
    timer?.invalidate()  
  }
  
  func start() {
    if !isPrepared {
      prepare()
      isPrepared = true
    }
    timeline.playAll()   
    
    let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak timeline] _ in
      timeline?.debug()
    }
    self.timer = timer
    
    RunLoop.current.add(timer, forMode: .common)
  }
  
  func prepare() {
    do {
      try AudioSessionManager.shared.activate()
      
      let aTrack = timeline.addTrack(
        name: "A",
        file: .test1(),
        offset: nil
      )
      
      aTrack.set(rate: 1)
      
//      timeline.addTrack(
//        name: "B",
//        file: .test2(),
//        offset: .time(5)
//      )
      
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
    let url = Bundle.main.url(forResource: "Social Media Has Ruined Photography", withExtension: "mp3")!
    return try! AVAudioFile(forReading: url)
  }
  
  static func test2() -> AVAudioFile {
    let url = Bundle.main.url(forResource: "overwhelmed - Peter Mckinnon", withExtension: "mp3")!
    return try! AVAudioFile(forReading: url)
  }
}

struct Clock {
  
  private var isRunning: Bool = false
  
  private var elapsed: HostTime {
    let elapsedTime = HostTime.now - started    
    return elapsedTime
  }
  
  var started: HostTime = .now  
  var offset: HostTime = .zero
  
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
