import Foundation
import WhisperKit

public enum WhisperKitWrapper {

  public enum Error: Swift.Error {
    case failedToTranscribe
  }

  public struct Result: Sendable {
    let audioFileURL: URL
    let segments: [AbstractSegment]
  }
  
  // Model information
  public struct Model: Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
  }
  
  // Available models with descriptions
  public static let availableModels: [Model] = [
    Model(name: "small.en", description: "Balanced speed and accuracy"),
    Model(name: "medium.en", description: "Better accuracy, slower")
  ]

  public static func run(url input: URL, model: String) async throws -> Result {

    let hasSecurityScope = input.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        input.stopAccessingSecurityScopedResource()
      }
    }

    // Initialize WhisperKit with specified model
    let pipe = try await WhisperKit(model: model)

    let results: [TranscriptionResult] = try await pipe.transcribe(
      audioPath: input.path(percentEncoded: false),
      decodeOptions: .init(
        language: "en",
        skipSpecialTokens: true,
        wordTimestamps: true,
        suppressBlank: true
      )
    ) { @Sendable progress in
      return true
    }

    let result = results.first

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
