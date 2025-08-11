import AVFoundation
import Foundation

public enum AudioExtractorError: Error {
  case noAudioTrack
  case failedToCreateCompositionTrack
  case failedToInsertTimeRange(Error)
  case failedToRemoveExistingFile(Error)
  case failedToCreateOutputDirectory(Error)
  case exportSessionCreationFailed
  case exportCancelled
  case exportFailed(Error?)
  case exportStatusUnknown
  case underlying(Error)
}

public enum AudioExtractor {
  
  /// Extracts audio from a video file and returns the path to an m4a audio file
  /// - Parameter videoURL: URL to the video file
  /// - Returns: URL to the extracted m4a audio file
  public nonisolated static func extractAudio(from videoURL: URL) async throws(AudioExtractorError) -> URL {
    
    let hasSecurityScope = videoURL.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        videoURL.stopAccessingSecurityScopedResource()
      }
    }
    
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
        throw AudioExtractorError.failedToCreateCompositionTrack
      }
      try audioCompositionTrack.insertTimeRange(
        await audioAssetTrack.load(.timeRange),
        of: audioAssetTrack,
        at: CMTime.zero
      )
    } catch let error as AudioExtractorError {
      throw error
    } catch {
      throw AudioExtractorError.failedToInsertTimeRange(error)
    }
    
    // Get url for output - ensure we write to a valid location
    let outputURL: URL
    
    // Check if the original URL's directory is writable
    let originalDirectory = videoURL.deletingLastPathComponent()
    if FileManager.default.isWritableFile(atPath: originalDirectory.path) {
      // Use the same directory as the input file
      outputURL = videoURL.updatingPathExtension("m4a")
    } else {
      // Fall back to temporary directory
      let tempDirectory = FileManager.default.temporaryDirectory
      let fileName = videoURL.deletingPathExtension().lastPathComponent
      outputURL = tempDirectory
        .appendingPathComponent(fileName)
        .appendingPathExtension("m4a")
    }
    
    // Remove existing file if it exists
    if FileManager.default.fileExists(atPath: outputURL.path) {
      do {
        try FileManager.default.removeItem(atPath: outputURL.path)
      } catch {
        throw AudioExtractorError.failedToRemoveExistingFile(error)
      }
    }
    
    // Ensure the parent directory exists
    let outputDirectory = outputURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: outputDirectory.path) {
      do {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
      } catch {
        throw AudioExtractorError.failedToCreateOutputDirectory(error)
      }
    }
    
    // Create an export session
    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetPassthrough
    ) else {
      throw AudioExtractorError.exportSessionCreationFailed
    }
    exportSession.outputFileType = AVFileType.m4a
    exportSession.outputURL = outputURL
    
    await exportSession.export()
    
    switch exportSession.status {
    case .completed:
      break // Success
    case .cancelled:
      throw AudioExtractorError.exportCancelled
    case .failed:
      throw AudioExtractorError.exportFailed(exportSession.error)
    case .unknown:
      throw AudioExtractorError.exportStatusUnknown
    case .exporting, .waiting:
      // These should not happen after export() completes
      throw AudioExtractorError.exportStatusUnknown
    @unknown default:
      throw AudioExtractorError.exportStatusUnknown
    }
    
    return outputURL
  }
}
