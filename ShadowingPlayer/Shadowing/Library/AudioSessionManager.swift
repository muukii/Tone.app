import AVFoundation

@MainActor
public final class AudioSessionManager {

  public enum Mode {
    case playback
    case playAndRecord
    case disabled
  }
  
  public static let shared = AudioSessionManager()
  
  private var mode: Mode = .disabled
  
  private var instance: AVAudioSession {
    AVAudioSession.sharedInstance()
  }
  
  private init() {}
  
  public func setInitialState() {            
    do {
      try instance.setCategory(
        .playback,
        mode: .default,
        policy: .default,
        options: [.mixWithOthers]
      )
      try instance.setActive(true, options: [])
    } catch {
      Log.error("Failed to set audio session category: \(error)")
    }
    mode = .playback

  }
  
  public func activate() throws {    
    guard mode != .disabled else { return }
    
    try instance.setActive(false, options: [])

    try instance.setCategory(
      .playback,
      mode: .default,
      policy: .default,
      options: [.duckOthers]
    )
    
    try instance.setActive(true, options: [])
    
    mode = .playback
  }
  
  public func activateForRecording() throws {
    
    guard mode != .disabled else {
      return
    }
    
    try instance.setActive(false, options: [])
    
    try instance.setCategory(
      .playAndRecord,
      mode: .spokenAudio,
      policy: .default,
      options: []
    )
    
    try instance.setActive(true, options: [])
    
    mode = .playAndRecord
  }
  
  public func deactivate() throws {
    guard mode != .disabled else { return }
    
    setInitialState()
    
    mode = .disabled
  }
  
} 
