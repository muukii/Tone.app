import AVFoundation

@MainActor
public final class AudioSessionManager {
  
  public static let shared = AudioSessionManager()
  
  private var instance: AVAudioSession {
    AVAudioSession.sharedInstance()
  }
  
  private init() {}
  
  // 初期状態に設定する（アプリ起動時や初期状態に戻す時に使用）
  public func resetToDefaultState() {
    Log.debug("AudioSessionManager.resetToDefaultState() called")
    do {
      // 再生のみの状態にして、AirPodsの音質を保つ
      try instance.setCategory(
        .playback,
        mode: .default,
        options: [.allowBluetooth, .allowBluetoothA2DP]
      )
      try instance.setActive(true)
      Log.debug("AudioSessionManager reset to default state - category: playback, mode: default, active: true")
    } catch {
      Log.error("Failed to reset audio session to default state: \(error)")
    }
  }
  
  // アプリ起動時に一度だけ呼ぶ（resetToDefaultStateのエイリアス）
  public func initialize() {
    Log.debug("AudioSessionManager.initialize() called")
    resetToDefaultState()
  }
  
  // 録音時に呼ぶ（必要に応じて）
  public func optimizeForRecording() throws {
    Log.debug("AudioSessionManager.optimizeForRecording() called")
    // 録音のためにカテゴリを変更
    try instance.setCategory(
      .playAndRecord,
      mode: .videoChat,  // videoChatモードは録音品質とレイテンシのバランスが良い
      options: [.allowBluetooth, .allowBluetoothA2DP]
    )
    Log.debug("AudioSessionManager changed to playAndRecord category with videoChat mode for recording")
  }
  
  // 再生専用時に呼ぶ（必要に応じて）
  public func optimizeForPlayback() throws {
    Log.debug("AudioSessionManager.optimizeForPlayback() called")
    try instance.setMode(.default)
    Log.debug("AudioSessionManager mode changed to default for playback")
  }
  
} 
