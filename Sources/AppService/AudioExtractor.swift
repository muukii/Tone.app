import AVFoundation
import Foundation

public enum AudioExtractorError: Error {
  case noAudioTrack
  case exportFailed
  case underlying(Error)
}

public enum AudioExtractor {
  
  /// Extracts audio from a video file and returns the path to an m4a audio file
  /// - Parameter videoURL: URL to the video file
  /// - Returns: URL to the extracted m4a audio file
  public nonisolated static func extractAudio(from videoURL: URL) async throws -> URL {
    
    // Create a composition
    let composition = AVMutableComposition()
    do {
      let asset = AVURLAsset(url: videoURL)
      guard let audioAssetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
        throw AudioExtractorError.noAudioTrack
      }
      guard
        let audioCompositionTrack = composition.addMutableTrack(
          withMediaType: AVMediaType.audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
      else {
        throw AudioExtractorError.exportFailed
      }
      try audioCompositionTrack.insertTimeRange(
        await audioAssetTrack.load(.timeRange),
        of: audioAssetTrack,
        at: CMTime.zero
      )
    } catch {
      throw AudioExtractorError.underlying(error)
    }
    
    // Get url for output
    let outputURL = videoURL.updatingPathExtension("m4a")
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(atPath: outputURL.path)
    }
    
    // Create an export session
    let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetPassthrough
    )!
    exportSession.outputFileType = AVFileType.m4a
    exportSession.outputURL = outputURL
    
    await exportSession.export()
    
    guard case exportSession.status = AVAssetExportSession.Status.completed else {
      throw AudioExtractorError.exportFailed
    }
    
    return outputURL
  }
}
