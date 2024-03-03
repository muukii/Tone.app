import Foundation
import WhisperKit

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
    let pipe = try await WhisperKit(model: "tiny.en")

    let result = try await pipe.transcribe(
      audioPath: input.path(percentEncoded: false),
      decodeOptions: .init(
        language: "en",
        skipSpecialTokens: true,
        wordTimestamps: true
      )
    ) { progress in
      return true
    }

    guard let result else {
      throw Error.failedToTranscribe
    }

    let segments = result.segments.flatMap {

      if let words = $0.words {
        return words.map {
          AbstractSegment(
            startTime: TimeInterval($0.start),
            endTime: TimeInterval($0.end),
            text: $0.word
          )
        }
      } else {
        return [
          AbstractSegment(
            startTime: TimeInterval($0.start),
            endTime: TimeInterval($0.end),
            text: $0.text
          )
        ]
      }

    }

    let r = Result(audioFileURL: input, segments: segments)

    return r
  }
}
