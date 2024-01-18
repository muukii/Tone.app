import YouTubeKit
import AVFoundation

enum YouTubeDownloaderError: Error {
  case streamNotFound
}

enum YouTubeDownloader {

  /// returns audio file in temporary dir
  static func run(url: URL) async throws -> URL {

    let video = YouTube(url: url)

    let stream = try await video.streams.filter {
      $0.includesVideoAndAudioTrack && $0.fileExtension == .mp4
    }
      .highestResolutionStream()

    Log.debug("\(String(describing: stream))")

    guard let stream else {
      Log.error("Could not find a url to the video")
      throw YouTubeDownloaderError.streamNotFound
    }

    Log.debug("Download => \(stream.url)")

    let (downloadedTempURL, _) = try await URLSession.shared.download(from: stream.url)

    let destinationURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")

    try FileManager.default.moveItem(at: downloadedTempURL, to: destinationURL)

    Log.debug("Download completed => \(downloadedTempURL)")

    return try await AudioExtractor.run(videoURL: destinationURL)

  }

}

enum AudioExtractorError: Error {
  case somethingFailed
  case underlying(Error)
}

enum AudioExtractor {

  // returns m4a file url
  static func run(videoURL: URL) async throws -> URL {

    // Create a composition
    let composition = AVMutableComposition()
    do {
      let sourceUrl = videoURL
      let asset = AVURLAsset(url: sourceUrl)
      guard let audioAssetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
        throw AudioExtractorError.somethingFailed
      }
      guard
        let audioCompositionTrack = composition.addMutableTrack(
          withMediaType: AVMediaType.audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
      else {
        throw AudioExtractorError.somethingFailed
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
      throw AudioExtractorError.somethingFailed
    }

    return outputURL
  }
}
