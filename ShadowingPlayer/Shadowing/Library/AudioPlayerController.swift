@preconcurrency import AVFoundation
import MediaPlayer
import StateGraph

enum AudioPlayerControllerError: Error {
  case fileLengthIsZero
}

@MainActor
final class AudioPlayerController: NSObject {
       
  final class Recording {

    let offsetToMain: TimeInterval

    let filePath: URL

    let writingFile: AVAudioFile

    init(
      offsetToMain: TimeInterval,
      destination: URL,
      format: AVAudioFormat
    ) throws {

      self.offsetToMain = offsetToMain

      let outputFile = try AVAudioFile(
        forWriting: destination,
        settings: format.settings
      )

      self.writingFile = outputFile
      self.filePath = destination

    }
    
    func makeReadingFile() throws -> AVAudioFile {
      try AVAudioFile(forReading: filePath)
    }
  }

  enum Repeating {
    case atEnd
    case range(start: Double, end: Double)
  }

  @GraphStored
  var isPlaying: Bool = false

  var isRecording: Bool {
    currentRecording != nil
  }

  @GraphStored
  var recordings: [Recording] = []

  @GraphStored
  private var currentRecording: Recording? = nil

  //  var isAppInBackground: Bool = false

  private var currentActiveEngine: AVAudioEngine?

  private let file: AVAudioFile

  private var currentTimerForLoop: Timer?

  var repeating: Repeating? = nil
  
  var cancellables: Set<AnyCancellable> = .init()
  
  private let timeline: AudioTimeline = .init()
  
  private(set) var mainTrack: AudioTimeline.Track?

  init(file: AVAudioFile) throws {

    self.file = file

    guard file.length > 0 else {
      throw AudioPlayerControllerError.fileLengthIsZero
    }
    
    let mainTrack = timeline.addTrack(
      trackType: .main,
      name: "Main",
      file: file
    )
    
//#if DEBUG
//    let subTrack1 = timeline.addTrack(
//      trackType: .sub,
//      name: "Sub",
//      file: file,
//      offset: .timeInMain(.from(timeInterval: 8.8499999999999996))
//    )
//#endif
    
    self.mainTrack = mainTrack

    super.init()

    // Listen for audio session interruptions (e.g., incoming call)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )
    // Listen for route changes (e.g., headphones unplug or Bluetooth device removed)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance()
    )
    
    withGraphTracking {
      $recordings.onChange { value in
        print("recordings", value)
      }
    }
    .store(in: &cancellables)
  }

  deinit {
    // Remove observers for notifications and remote commands
    NotificationCenter.default.removeObserver(self)
    Log.debug("deinit \(String(describing: self))")
  }

  @objc private func handleInterruption() {
    pause()
  }

  /// Handle audio route changes, such as headphones being unplugged or Bluetooth device removed
  @objc private func handleRouteChange(_ notification: Notification) {
    guard let info = notification.userInfo,
      let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
      reason == .oldDeviceUnavailable
    else {
      return
    }
    pause()
  }

  func prepare() throws {
    try currentActiveEngine?.start()
  }

  func stopRecording() {

    guard let currentRecording, let currentActiveEngine else {
      return
    }
    
//    try! AudioSessionManager.shared.activate()
    
    Log.debug("Stop recording")

    currentRecording.writingFile.close()

    recordings.append(currentRecording)
    
    addRecordingToPlay(recording: currentRecording)

    self.currentRecording = nil

  }
  
  private func addRecordingToPlay(recording: Recording) {
    do {
      timeline.addTrack(
        trackType: .sub,
        name: "Recording",
        file: try recording.makeReadingFile(),
        offset: .timeInMain(.from(timeInterval: recording.offsetToMain))
      )
    } catch {
      assertionFailure()
    }
    timeline.attach(to: currentActiveEngine!)
  }
    
  func startRecording() {

    guard isPlaying, let currentActiveEngine else {
      return
    }

    guard isRecording == false else {
      return
    }
    
    assert(MicrophonePermissionManager().isGranted, "Microphone permission must be granted before calling startRecording()")

    // take a value before pause   
    
    guard let currentTimeInMain = self.mainTrack!.currentTime() else {
      return
    }
    
    Log.debug("Start recording at: \(currentTimeInMain)")

//    pause()

//    try! AudioSessionManager.shared.activateForRecording()

    do {
      
      let format = currentActiveEngine.inputNode.outputFormat(forBus: 0)
      
      Log.info("Recording inputNode.outputFormat: \(format)")

      let recording = try Recording.init(
        offsetToMain: currentTimeInMain,
        destination: URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf"),
        format: format
      )

      self.currentRecording = recording

      print("outputFile: \(recording.filePath)")

//      try play()
    } catch {
      assertionFailure()
    }

  }
  
  private var hasSetTap: Bool = false
  
  private func setTap() {
    
    guard !hasSetTap, let currentActiveEngine else {
      return
    }
    hasSetTap = true
    
    let format = currentActiveEngine.inputNode.outputFormat(forBus: 0)

    currentActiveEngine.inputNode.installTap(
      onBus: 0,
      bufferSize: 4096,
      format: format
    ) { @Sendable [weak self] (buffer, time) in
      print("Audio buffer received at time: \(time)")
      do {
        try self?.$currentRecording.wrappedValue?.writingFile.write(from: buffer)
      } catch {
        Log.error("Failed to write audio buffer: \(error)")
      }
    }
  }
  
  private func removeTap() {
    
    guard let currentActiveEngine else {
      return
    }
    
    currentActiveEngine.inputNode.removeTap(onBus: 0)
    hasSetTap = false
  }

  func setSpeed(speed: Double) {

    assert(speed >= (1 / 32) && speed <= 32)

    mainTrack?.set(rate: Float(speed))
  }

  private func createEngine() {
    
    // making AVAudioEngine triggers AVAudioSession to start
        
    guard currentActiveEngine == nil else {
      return
    }
    
    try! AudioSessionManager.shared.activate()
    
    let newEngine = AVAudioEngine()
    self.currentActiveEngine = newEngine
    
    timeline.attach(to: newEngine)
    
    setTap()
  }

  func play() throws {

    if currentActiveEngine == nil {
      createEngine()
    }

    isPlaying = true

    if currentActiveEngine?.isRunning == false {
      try currentActiveEngine?.start()
    }
    
    timeline.seek(position: mainTrack!.pausedPosition, in: .main)
        
    timeline.resume()

    currentTimerForLoop = Timer.init(timeInterval: 0.005, repeats: true) { [weak self] _ in

      MainActor.assumeIsolated { [weak self] () -> Void in

        guard let self else { return }
        
        switch self.repeating {
        case .atEnd:
          
          if let current = self.mainTrack!.currentTime() {
            if current >= self.file.duration {
              self.seek(positionInMain: 0)
            }
          }
          
        case .range(let start, let end):
          
          if let current = self.mainTrack!.currentTime() {
            
            if current >= end {
              self.seek(positionInMain: start)
            }
          }

        case nil:

          if let current = self.mainTrack!.currentTime() {
            if current >= self.file.duration {
              self.pause()
            }
          }

        }

      }

    }

    RunLoop.main.add(currentTimerForLoop!, forMode: .common)

  }

  func pause() {
    
    guard isPlaying else {
      return
    }

    isPlaying = false    
    
    timeline.pause()    

    currentTimerForLoop?.invalidate()
    currentTimerForLoop = nil

  }

  func seek(positionInMain: TimeInterval) {
    Log.debug("Seek \(positionInMain)")
    createEngine()
    timeline.seek(position: positionInMain, in: .main)

  }
  
  

}

extension AVAudioFile {

  var duration: TimeInterval {
    Double(length) / processingFormat.sampleRate
  }

  func frame(at position: TimeInterval) -> AVAudioFramePosition {
    let sampleRate = processingFormat.sampleRate
    return AVAudioFramePosition(sampleRate * position)
  }

  func frames(from position: TimeInterval) -> AVAudioFrameCount {
    let sampleRate = processingFormat.sampleRate

    let startFrame = AVAudioFramePosition(sampleRate * position)
    let endFrame = AVAudioFramePosition(length)
    let frameCount = AVAudioFrameCount(endFrame - startFrame)

    return frameCount
  }

}

#if DEBUG && canImport(SwiftUI)

  import SwiftUI
  import AppService
//
//@MainActor
//private struct AudioPlayerControllerPreview: View {
//
//  let player: AudioPlayerController = try! .init(
//    file: .init(forReading: Item.social.audioFileURL)  //,
//    //    overlappingFile: .init(forReading: Item.overwhelmed.audioFileURL)
//  )
//
//  var body: some View {
//    VStack {
//      Button("Play") {
//        try? player.play()
//      }
//      Button("Stop") {
//        player.pause()
//      }
//    }
//  }
//
//}

#endif
