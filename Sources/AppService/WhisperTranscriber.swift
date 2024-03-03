
import WhisperKit
import Foundation

enum WhisperKitWrapper {

  enum Error: Swift.Error {
    case failedToTranscribe
  }

  struct Result {
    let audioFileURL: URL
    let segments: [AbstractSegment]
  }

  static func run(url input: URL) async throws -> Result {

    let hasSecurityScope = input.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        input.stopAccessingSecurityScopedResource()
      }
    }

    // Initialize WhisperKit with default settings
    let pipe = try await WhisperKit()
    let result = try await pipe.transcribe(audioPath: input.path(percentEncoded: false), decodeOptions: .init(language: "English"))

    guard let result else {
      throw Error.failedToTranscribe
    }

    let segments = result.segments.map {
      AbstractSegment(
        startTime: TimeInterval($0.start),
        endTime: TimeInterval($0.end),
        text: $0.text
      )
    }

    let r = Result(audioFileURL: input, segments: segments)

    return r
  }
}
