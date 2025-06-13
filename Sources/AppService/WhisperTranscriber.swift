import Foundation
import WhisperKit

public enum WhisperKitWrapper {

  public enum Error: Swift.Error {
    case failedToTranscribe
    case failedToDownloadModel
  }

  public  struct Result: Sendable {
    let audioFileURL: URL
    let segments: [AbstractSegment]
  }
  
  // Available models - using static list as WhisperKit doesn't expose fetchAvailableModels
  public static let availableModels = [
    "tiny",
    "tiny.en",
    "base",
    "base.en", 
    "small",
    "small.en",
    "medium",
    "medium.en",
    "large-v2",
    "large-v3"
  ]
  
  // Fetch available models - returns static list for now
  public static func fetchAvailableModels() async -> [String] {
    // WhisperKit doesn't currently have a fetchAvailableModels method
    // Return the static list instead
    return availableModels
  }
  
  // Model description
  public static func getModelDescription(for modelName: String) -> String {
    switch modelName {
    case "tiny", "tiny.en": return "Fastest, least accurate"
    case "base", "base.en": return "Fast, good for simple audio"
    case "small", "small.en": return "Balanced speed and accuracy"
    case "medium", "medium.en": return "Better accuracy, slower"
    case "large-v2", "large-v3": return "Best accuracy, slowest"
    default: return ""
    }
  }
  
  // Get list of downloaded models
  public static func getDownloadedModels() async -> [String] {
    // Check which models exist in the WhisperKit model directory
    var downloadedModels: [String] = []
    
    for model in availableModels {
      // Try to initialize WhisperKit with the model to check if it's downloaded
      do {
        _ = try await WhisperKit(model: model)
        downloadedModels.append(model)
      } catch {
        // Model not downloaded, skip
        continue
      }
    }
    
    return downloadedModels
  }
  
  // Download a specific model
  public static func downloadModel(
    _ modelName: String,
    progressHandler: @escaping @Sendable (Double) -> Void = { _ in }
  ) async throws {
    do {
      _ = try await WhisperKit.download(variant: modelName, progressCallback: { @Sendable progress in
        progressHandler(progress.fractionCompleted)
      })
    } catch {
      throw Error.failedToDownloadModel
    }
  }
  
  // Check if a model is downloaded
  public static func isModelDownloaded(_ modelName: String) async -> Bool {
    let downloadedModels = await getDownloadedModels()
    return downloadedModels.contains(modelName)
  }
  
  // Delete a downloaded model
  public static func deleteModel(_ modelName: String) async throws {
    // WhisperKit doesn't provide a direct delete method
    // For now, we'll need to manually delete model files from the cache directory
    // This is a placeholder - actual implementation would need to find and delete model files
    
    // Get the model directory path
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let modelsPath = documentsPath.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
    let modelPath = modelsPath.appendingPathComponent(modelName)
    
    do {
      try FileManager.default.removeItem(at: modelPath)
    } catch {
      throw Error.failedToDownloadModel
    }
  }

  public static func run(url input: URL) async throws -> Result {

    let hasSecurityScope = input.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        input.stopAccessingSecurityScopedResource()
      }
    }

    // Get selected model from UserDefaults
    let selectedModel = UserDefaults.standard.string(forKey: "selectedWhisperModel") ?? "small.en"

    // Initialize WhisperKit with selected model
    let pipe = try await WhisperKit(model: selectedModel)

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
