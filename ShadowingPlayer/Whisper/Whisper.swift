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

struct WhisperView: View {

  struct Result: Hashable {

    func hash(into hasher: inout Hasher) {
      audioFileURL.hash(into: &hasher)
    }

    var segments: [Segment]
    var audioFileURL: URL
  }

  @State var result: Result?

  let usingModel: WhisperModelRef = .enMedium

  var body: some View {
    NavigationStack {
      VStack {
        WhisperModelDownloadView(modelRef: usingModel)
        Button("Transcribe") {

          let input = Item.overwhelmed.audioFileURL
          let destination = URL.temporaryDirectory.appending(path: "audio\(UUID().uuidString).wav")

          Task {

            try await withBackground {
              try await FormatConverter(
                inputURL: input,
                outputURL: destination,
                options: .init(pcmFormat: .wav, sampleRate: 16000, bitDepth: 16, channels: 1)
              ).start()

              let params = WhisperParams.default

              params.token_timestamps = true
              params.max_len = 2
              params.split_on_word = true

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

              await MainActor.run {
                self.result = .init(segments: segments, audioFileURL: input)
              }
            }

          }

        }

      }
      .navigationTitle("Transcribe")
      .navigationDestination(item: $result) { result in
        PlayerView<PlayerListFlowLayoutView>(
          playerController: {
            try! .init(
              title: "hello",
              audioFileURL: result.audioFileURL,
              segments: result.segments.map { AbstractSegment.init(segment: $0) }
            )
          },
          actionHandler: { _ in }
        )
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

  var storedModelURL: URL {
    URL.temporaryDirectory.appending(path: "whisper_model_\(name).bin")
  }

  var storedCoreMLModelURL: URL {
    URL.temporaryDirectory.appending(path: "whisper_model_\(name)-encoder.mlmodelc")
  }
}

struct WhisperModelDownloadView: View {

  let modelRef: WhisperModelRef

  var body: some View {

    Button("Download") {

      Task {

        do {

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
        } catch {
          Log.error("\(error.localizedDescription)")
        }
      }

    }
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

#Preview {
  WhisperModelDownloadView(modelRef: .enTiny)
}
