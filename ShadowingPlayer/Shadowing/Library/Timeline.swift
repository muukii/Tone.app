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
      track.node.play()
    }
  }

  func pause() {
    for track in tracks {
      track.node.pause()
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
}

import SwiftUI

@MainActor
private final class Controller: ObservableObject {
  
  let timeline: Timeline = .init()
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
      
      timeline.addTrack(
        name: "test",
        file: .test1(),
        offset: 0
      )
      
      timeline.addTrack(
        name: "test",
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
