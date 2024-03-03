//
//  Whisper.swift
//  Tone
//
//  Created by Muukii on 2024/01/16.
//  Copyright © 2024 MuukLab. All rights reserved.
//

import AVFAudio
import AppService
import AudioKit
import SwiftUI
import SwiftWhisper
import ZipArchive

enum WhisperTranscriber {

  struct Result {
    let audioFileURL: URL
    let segments: [Segment]
  }

  static func run(url input: URL, using usingModel: WhisperModelRef) async throws -> Result {

    let hasSecurityScope = input.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        input.stopAccessingSecurityScopedResource()
      }
    }

    let destination = URL.temporaryDirectory.appending(path: "audio\(UUID().uuidString).wav")

    try await FormatConverter(
      inputURL: input,
      outputURL: destination,
      options: .init(pcmFormat: .wav, sampleRate: 16000, bitDepth: 16, channels: 1)
    ).start()

    let params = WhisperParams.default

    params.token_timestamps = true
    params.max_len = 2
    params.split_on_word = true
    params.language = .english

    let whisper = Whisper(
      fromFileURL: usingModel.storedModelURL,
      withParams: params
    )

    let file = try AVAudioFile(forReading: destination)
    let buffer = AVAudioPCMBuffer(
      pcmFormat: file.processingFormat,
      frameCapacity: .init(file.length)
    )!
    try file.read(into: buffer)

    let segments = try await whisper.transcribe(audioFrames: buffer.toFloatChannelData()![0])

    return .init(audioFileURL: input, segments: segments)
  }

}

enum WhisperModelDownloader {

  static func run(modelRef: WhisperModelRef) async throws {

    async let (modelFileURL, _) = URLSession.shared.download(
      from: modelRef.modelURL,
      delegate: nil
    )
    async let (coremlModelZipURL, _) = URLSession.shared.download(
      from: modelRef.coremlModelZipURL,
      delegate: nil
    )

    let destinationURL = modelRef.storedModelURL

    // model
    do {
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
      }
      try FileManager.default.moveItem(at: await modelFileURL, to: destinationURL)
      Log.debug("Model done \(destinationURL.path(percentEncoded: true))")
    }

    // coreml model
    do {

      let coremlModelZipURL = try await coremlModelZipURL

      let unzippedTmp = URL.temporaryDirectory
      let result = SSZipArchive.unzipFile(
        atPath: coremlModelZipURL.path(percentEncoded: true),
        toDestination: unzippedTmp.path()
      )

      let target = unzippedTmp.appending(
        path: modelRef.coremlModelZipURL.lastPathComponent.replacingOccurrences(
          of: "." + modelRef.coremlModelZipURL.pathExtension,
          with: ""
        )
      )

      let destinationURL = modelRef.storedCoreMLModelURL

      if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
      }
      try FileManager.default.moveItem(at: target, to: destinationURL)
      //            Log.debug("Model done \(destinationURL.path(percentEncoded: true))")

      if result {
        Log.debug("CoreML Model done")
      } else {
        print("error")
      }
    }

  }

}

struct WhisperModelRef {

  let modelURL: URL
  let coremlModelZipURL: URL
  let name: String

  init(name: String, modelURL: URL, coremlModelZipURL: URL) {
    self.name = name
    self.modelURL = modelURL
    self.coremlModelZipURL = coremlModelZipURL
  }

  static let enTiny: Self = .init(
    name: "EnTiny",
    modelURL: URL(
      string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin"
    )!,
    coremlModelZipURL: URL(
      string:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-encoder.mlmodelc.zip"
    )!
  )

  static let enBase: Self = .init(
    name: "EnBase",
    modelURL: URL(
      string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
    )!,
    coremlModelZipURL: URL(
      string:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-encoder.mlmodelc.zip"
    )!
  )

  static let enSmall: Self = .init(
    name: "EnSmall",
    modelURL: URL(
      string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin"
    )!,
    coremlModelZipURL: URL(
      string:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-encoder.mlmodelc.zip"
    )!
  )

  static let enMedium: Self = .init(
    name: "EnMedium",
    modelURL: URL(
      string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin"
    )!,
    coremlModelZipURL: URL(
      string:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-encoder.mlmodelc.zip"
    )!
  )

  static let enLarge: Self = .init(
    name: "EnLarge",
    modelURL: URL(
      string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
    )!,
    coremlModelZipURL: URL(
      string:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-encoder.mlmodelc.zip"
    )!
  )

  func isDownloaded() async -> Bool {
    FileManager.default.fileExists(atPath: storedModelURL.path)
      && FileManager.default.fileExists(atPath: storedCoreMLModelURL.path)
  }

  var storedModelURL: URL {
    URL.applicationSupportDirectory.appending(path: "whisper_model_\(name).bin")
  }

  var storedCoreMLModelURL: URL {
    URL.applicationSupportDirectory.appending(path: "whisper_model_\(name)-encoder.mlmodelc")
  }
}

extension FormatConverter {

  func start() async throws {
    return try await withCheckedThrowingContinuation { c in
      start { error in
        if let error {
          c.resume(throwing: error)
        } else {
          c.resume()
        }
      }
    }
  }

}
