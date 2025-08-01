import YouTubeKit
import AVFoundation
import AppService

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

    return try await AudioExtractor.extractAudio(from: destinationURL)

  }

  private final class TaskDeletage: NSObject, URLSessionTaskDelegate {

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
