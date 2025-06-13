import YouTubeKit
import AVFoundation

enum YouTubeDownloaderError: Error {
  case streamNotFound
}

enum YouTubeDownloader {
  
  static let session = URLSession(configuration: .default)

  /// returns audio file in temporary dir
  static nonisolated func run(url: URL) async throws -> URL {

    let video = YouTube(url: url)

    let stream = try await video.streams.filter {
      [FileExtension.aac, .m4a, .mp4, .mp3].contains($0.fileExtension)
    }
      .filterAudioOnly()
      .highestAudioBitrateStream()

    Log.debug("\(String(describing: stream))")

    guard let stream else {
      Log.error("Could not find a url to the video")
      throw YouTubeDownloaderError.streamNotFound
    }

    Log.debug("Download => \(stream.url)")

    let delegate = TaskDeletage()

    let request = URLRequest(
      url: stream.url,
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
    )

    let (downloadedTempURL, _) = try await session.download(for: request, delegate: delegate)

    withExtendedLifetime(delegate) {}

    let destinationURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")

    try FileManager.default.moveItem(at: downloadedTempURL, to: destinationURL)

    Log.debug("Download completed => \(downloadedTempURL)")

    return try await AudioExtractor.run(videoURL: destinationURL)

  }

  private nonisolated final class TaskDeletage: NSObject, URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
      print("task created")
    }

    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
      print("task waiting for connectivity")
    }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didCompleteWithError error: Error?
    ) {
      Log.debug("task completed")
    }

    func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didWriteData bytesWritten: Int64,
      totalBytesWritten: Int64,
      totalBytesExpectedToWrite: Int64
    ) {

      let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

      print(progress)
    }
  }

}

enum AudioExtractorError: Error {
  case somethingFailed
  case underlying(Error)
}

enum AudioExtractor {

  // returns m4a file url
  nonisolated static func run(videoURL: URL) async throws -> URL {

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
