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
    do {
      try optimizeForRecording()
    } catch {
      Log.error("AudioSessionManager.resetToDefaultState() failed with error: \(error)")      
    }
  }

  // アプリ起動時に一度だけ呼ぶ（resetToDefaultStateのエイリアス）
  public func initialize() {
    Log.debug("AudioSessionManager.initialize() called")
    resetToDefaultState()
  }

  public func optimizeForRecording() throws {
    Log.debug("AudioSessionManager.optimizeForRecording() called")
    // 録音のためにカテゴリを変更
    try instance.setCategory(
      .playAndRecord,
      mode: .videoChat,  // videoChatモードは録音品質とレイテンシのバランスが良い
      options: [.allowBluetoothHFP, .allowBluetoothA2DP]
    )
    //    try instance.setActive(true)
    Log.debug(
      "AudioSessionManager changed to playAndRecord category with videoChat mode for recording"
    )
  }

  // 再生専用時に呼ぶ（必要に応じて）
  public func optimizeForPlayback() throws {
    Log.debug("AudioSessionManager.resetToDefaultState() called")
    // 再生のみの状態にして、AirPodsの音質を保つ
    try instance.setCategory(
      .playback,
      mode: .default,
      options: [.allowBluetoothHFP, .allowBluetoothA2DP]
    )
    try instance.setActive(true)
    Log.debug(
      "AudioSessionManager reset to default state - category: playback, mode: default, active: true"
    )
  }

  public func isHeadphoneConnected() -> Bool {
    let currentRoute = instance.currentRoute
    for output in currentRoute.outputs {
      switch output.portType {
      case .headphones, .bluetoothA2DP, .bluetoothHFP, .airPlay:
        return true
      default:
        break
      }
    }
    return false
  }

}
