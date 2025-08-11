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
  private var recordingEngine: AVAudioEngine?  // 録音専用エンジン

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
    // 録音エンジンのクリーンアップ
    if let recordingEngine = recordingEngine {
      recordingEngine.inputNode.removeTap(onBus: 0)
      recordingEngine.stop()
    }
    
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

    guard let currentRecording else {
      return
    }
    
    // 録音エンジンのタップを削除して停止
    if let recordingEngine = recordingEngine {
      recordingEngine.inputNode.removeTap(onBus: 0)
      recordingEngine.stop()
      self.recordingEngine = nil
    }
    
    // 再生専用に戻す
    try? AudioSessionManager.shared.optimizeForPlayback()
    
    Log.debug("Stop recording")

    currentRecording.writingFile.close()

    recordings.append(currentRecording)
    
    addRecordingToPlay(recording: currentRecording)

    self.currentRecording = nil

  }
  
  private func addRecordingToPlay(recording: Recording) {
    do {
      let recordingTrack = timeline.addTrack(
        trackType: .sub,
        name: "Recording",
        file: try recording.makeReadingFile(),
        offset: .timeInMain(.from(timeInterval: recording.offsetToMain))
      )
      // 録音トラックの音量を大幅に増幅
      recordingTrack.volume = 2.0  // 基本音量を200%に
      recordingTrack.gain = 20.0   // EQで+20dBゲイン（約10倍増幅）
      // 合計で約20倍の増幅効果
    } catch {
      assertionFailure()
    }
    timeline.attach(to: currentActiveEngine!)
  }
    
  func startRecording() {

    guard isPlaying else {
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

    // 録音時の最適化
    try? AudioSessionManager.shared.optimizeForRecording()
    
    // 録音専用エンジンを作成
    if recordingEngine == nil {
      recordingEngine = AVAudioEngine()
    }
    
    guard let recordingEngine else {
      return
    }

    do {
      // inputNodeのフォーマットを先に取得（エンジン起動前）
      let inputFormat = recordingEngine.inputNode.outputFormat(forBus: 0)
      
      // ミキサーノードを作成して接続（エンジンが動作するために必要）
      let mixerNode = AVAudioMixerNode()
      recordingEngine.attach(mixerNode)
      recordingEngine.connect(recordingEngine.inputNode, to: mixerNode, format: inputFormat)
      recordingEngine.connect(mixerNode, to: recordingEngine.mainMixerNode, format: inputFormat)
      
      // 録音エンジンを起動
      try recordingEngine.start()
      
      // フォーマットが有効かチェック（サンプルレートとチャンネル数が0でないこと）
      guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
        Log.error("Input node is not enabled. Format: \(inputFormat)")
        recordingEngine.stop()
        return
      }
      
      Log.info("Recording inputNode format: \(inputFormat)")

      let recording = try Recording.init(
        offsetToMain: currentTimeInMain,
        destination: URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf"),
        format: inputFormat
      )

      self.currentRecording = recording

      print("outputFile: \(recording.filePath)")
      
      // 録音エンジンにタップを設定
      setRecordingTap(with: nil)
    } catch {
      assertionFailure()
    }

  }
  
  // 録音エンジン用
  private func setRecordingTap(with format: AVAudioFormat?) {
    guard let recordingEngine else {
      return
    }

    recordingEngine.inputNode.installTap(
      onBus: 0,
      bufferSize: 4096,
      format: format  // nilの場合はinputNodeのデフォルトフォーマットが使用される
    ) { @Sendable [weak self] (buffer, time) in
      print("Audio buffer received at time: \(time)")
      do {
        try self?.$currentRecording.wrappedValue?.writingFile.write(from: buffer)
      } catch {
        Log.error("Failed to write audio buffer: \(error)")
      }
    }
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
    
    // AudioSessionは既にinitializeで設定済み
    let newEngine = AVAudioEngine()
    self.currentActiveEngine = newEngine
    
    timeline.attach(to: newEngine)
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
