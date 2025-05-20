import AVFoundation

final class Timeline {
  
  final class Track {
    
    var name: String
    let node: AVAudioPlayerNode
    let file: AVAudioFile
    
    var offset: TimeInterval
    
    var duration: TimeInterval {
      Double(file.length) / file.processingFormat.sampleRate
    }
    
    init(
      name: String,
      file: AVAudioFile,
      offset: TimeInterval
    ) {
      self.name = name
      self.node = .init()
      self.file = file
      self.offset = offset
    }
    
    func pause() {     
      node.stop()
    }
    
    func play() {                  
      node.play()
    }
    
    var playerTime: AVAudioTime? {
      guard let nodeTime = node.lastRenderTime else {
        return nil
      }
      
      guard let playerTime = node.playerTime(forNodeTime: nodeTime) else {
        return nil
      }
      
      return playerTime
    }
  }
  
  private var tracks: [Track] = []
  
  func addTrack(
    name: String,
    file: AVAudioFile,
    offset: TimeInterval = 0
  ) {
    let track = Track(
      name: name,
      file: file,
      offset: offset
    )
    tracks.append(track)
  }
  
  var totalDuration: TimeInterval {
    var duration: TimeInterval = 0
    for player in tracks {
      duration = max(player.duration, duration)
    }
    return duration
  }
  
  private var masterTrack: Track {
    tracks.filter {
      $0.offset == 0
    }
    .first!
  }
  
  var pausedRenderTime: AVAudioFramePosition = 0
  
  func seek(position: TimeInterval) {
    
    let masterTrack = self.masterTrack
    
    for track in tracks {
      
      let adjustedPosition = max(0, position - track.offset)
      
      if adjustedPosition < track.duration {
                
        if track === masterTrack {
          // record the paused point
          pausedRenderTime = track.file.frame(at: adjustedPosition)          
        }
        
        // Calculate the offset in time
        let _offset = track.offset - position
        
        // For tracks that start after the current position
        if _offset > 0 {
          // Schedule from beginning of the track
          let frameCount = AVAudioFrameCount(track.file.length)
          
          // Create timing for delayed start
          let timing = AVAudioTime(
            sampleTime: AVAudioFramePosition(_offset * track.file.processingFormat.sampleRate),
            atRate: track.file.processingFormat.sampleRate
          )
          
          track.node.scheduleSegment(
            track.file,
            startingFrame: 0,
            frameCount: frameCount,
            at: timing
          )
        } else {
          
          let frame = track.file.frame(at: adjustedPosition + track.offset)

          // For tracks that have already started or start at the current position
          let startingFrame = frame
          let frameCount = AVAudioFrameCount(track.file.length - startingFrame)
          
          // Immediate playback with no delay
          track.node.scheduleSegment(
            track.file,
            startingFrame: startingFrame,
            frameCount: frameCount,
            at: nil
          )
        }
      }
    }
  }
  
  func playAll(at position: TimeInterval? = nil) {
    
    if let position = position {
      seek(position: position)
    } else {
      if let pausedTime {
        seek(position: pausedTime)
      }
    }
    
    for track in tracks {
      track.play()
    }
  }
  
  func pause() {
    
    let time = masterTrack.playerTime?.sampleTime
    assert(time != nil)
    
    self.pausedTime = currentTime
    //    pausedRenderTime = (time ?? 0) + (pausedRenderTime)
    
    print("Paused", self.pausedTime ?? 0)
    
    for track in tracks {
      track.pause()
    }    
  }
  
  func stop() {
    for track in tracks {
      track.node.stop()
    }
  }
  
  func attach(to engine: AVAudioEngine) {
    for track in tracks {
      engine.attach(track.node)
      engine.connect(
        track.node,
        to: engine.mainMixerNode,
        format: track.file.processingFormat
      )
    }
  }
  
  func debug() {
    
    print(currentTime)
    
  }
  
  private var pausedTime: TimeInterval?
  
  private var currentTime: TimeInterval? {
    
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
  
  let timeline: Timeline = .init()
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
      
      timeline.addTrack(
        name: "A",
        file: .test1(),
        offset: 0
      )
      
      timeline.addTrack(
        name: "B",
        file: .test2(),
        offset: 5
      )
      
      timeline.attach(to: engine)
      
      try engine.start()
      
      timeline.seek(position: 0)
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

#Preview {
  
  
  
  return TimelineWrapper()
}
