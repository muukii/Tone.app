import AVFoundation

final class Timeline {

  final class Track {

    var pausedRenderTime: AVAudioFramePosition?
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
      let time = node.playerTime?.sampleTime
      assert(time != nil)
      pausedRenderTime = (time ?? 0) + (pausedRenderTime ?? 0)
      print(pausedRenderTime, file.processingFormat.sampleRate)
      node.stop()
    }

    func play() {                  
      _seek(frame: pausedRenderTime ?? 0)
      node.play()
    }
    
    private func _seek(frame: AVAudioFramePosition) {
      print("seek", frame)
      let remainingFrameCount = file.length - frame
      
      
      node.scheduleSegment(
        file,
        startingFrame: frame,
        frameCount: AVAudioFrameCount(remainingFrameCount),
        at: nil
      )
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
  
  private var masterTrack: Track? {
    tracks.filter {
      $0.offset == 0
    }
    .first
  }

  func seek(position: TimeInterval) {
    for track in tracks {
//      
//      track.node.scheduleSegment(
//        track.file,
//        startingFrame: nil,
//        frameCount: track.file.frames(from: adjustedPosition),
//        at: nil
//      )
//      track.node.scheduleFile(track.file, at: nil, completionHandler: nil)

      let adjustedPosition = max(0, position - track.offset)

      if adjustedPosition < track.duration {
        let frame = track.file.frame(at: adjustedPosition)
        track.node.scheduleSegment(
          track.file,
          startingFrame: frame,
          frameCount: track.file.frames(from: adjustedPosition),
          at: .init(
            sampleTime: AVAudioFramePosition(track.offset * track.file.processingFormat.sampleRate),
            atRate: track.file.processingFormat.sampleRate
          )
        )
      }
    }
  }

  func playAll(at position: TimeInterval? = nil) {

    if let position = position {
      seek(position: position)
    }

    for track in tracks {
      track.play()
    }
  }

  func pause() {
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
    
    for track in tracks {
//      print("Track: \(track.name) - time: \(track.node.playerTime)")
    }
    
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
