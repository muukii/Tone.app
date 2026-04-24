import Foundation

/// Manages recording files in a dedicated directory
enum RecordingFileManager {

  /// The dedicated directory for storing temporary recording files
  private static var recordingDirectory: URL {
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
  }

  /// Creates the recording directory if it doesn't exist
  private static func createRecordingDirectoryIfNeeded() {
    do {
      try FileManager.default.createDirectory(
        at: recordingDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      Log.error("Failed to create recording directory: \(error)")
    }
  }

  /// Generates a new URL for a recording file
  static func makeNewRecordingURL() -> URL {
    createRecordingDirectoryIfNeeded()
    return recordingDirectory.appendingPathComponent("\(UUID().uuidString).caf")
  }

  /// Cleans up all recording files
  static func cleanupAllRecordings() {
    do {
      let fileManager = FileManager.default

      // Get all files in the recording directory
      if fileManager.fileExists(atPath: recordingDirectory.path) {
        let contents = try fileManager.contentsOfDirectory(
          at: recordingDirectory,
          includingPropertiesForKeys: nil,
          options: []
        )

        // Delete each file
        for fileURL in contents {
          try fileManager.removeItem(at: fileURL)
        }

        Log.debug("Cleaned up \(contents.count) recording files")
      }
    } catch {
      Log.error("Failed to cleanup recordings: \(error)")
    }
  }
}