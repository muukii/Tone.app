import AVFoundation

@MainActor
public final class AudioSessionManager {
  
  public static let shared = AudioSessionManager()
  
  private var isActivated: Bool = false
  
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
  }
  
  public func activate() throws {
    guard !isActivated else { return }
    
    try instance.setActive(false, options: [])

    try instance.setCategory(
      .playback,
      mode: .default,
      policy: .default,
      options: [.duckOthers]
    )
    
    try instance.setActive(true, options: [])
    
    isActivated = true
  }
  
  public func deactivate() throws {
    guard isActivated else { return }
    
    setInitialState()
    
    isActivated = false
  }
  
} 
