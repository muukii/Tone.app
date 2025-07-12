import AVFoundation
import os.log

public struct MicrophonePermissionManager {
  
  public init() {}
  
  /// 現在のマイクパーミッションステータスを取得
  public var currentStatus: AVAudioApplication.recordPermission  {
    AVAudioApplication.shared.recordPermission
  }
  
  /// マイクパーミッションが許可されているかチェック
  public var isGranted: Bool {
    currentStatus == .granted
  }
  
  /// マイクパーミッションをリクエスト
  /// - Returns: 許可された場合はtrue、拒否された場合はfalse
  public func requestPermission() async -> Bool {
    switch currentStatus {
    case .granted:
      return true
    case .denied:
      return false
    case .undetermined:
      return await withCheckedContinuation { continuation in
        Task {
          await AVAudioApplication.requestRecordPermission()
          
          let permission = AVAudioApplication.shared.recordPermission
          
          switch permission {
          case .undetermined:
            assertionFailure()
          case .denied:
            Log.info("Microphone permission was denied.")            
            continuation.resume(returning: false)            
          case .granted:
            Log.info("Microphone permission was granted.")
            continuation.resume(returning: true)            
          @unknown default:
            assertionFailure()
          }          
        }      
      }
    @unknown default:
      return false
    }
  }
}
