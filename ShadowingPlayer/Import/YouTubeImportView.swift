import AppService
import SwiftUI
import YouTubeKit

struct YouTubeImportView: View {

  let service: Service
  let onComplete: @MainActor () -> Void

  init(service: Service, onComplete: @escaping @MainActor () -> Void) {
    self.service = service
    self.onComplete = onComplete
  }

  var body: some View {
    YouTubeImportContentView(
      onTranscribe: { url in
        do {

          let title = try await YouTube(url: url).metadata?.title

          let audio = try await YouTubeDownloader.run(url: url)
          let modelRef = WhisperModelRef.enSmall

          if await modelRef.isDownloaded() == false {
            try await WhisperModelDownloader.run(modelRef: modelRef)
          }

          let result = try await WhisperTranscriber.run(url: audio, using: modelRef)

          try await service.importItem(
            title: title ?? "(Not fetched)",
            audioFileURL: result.audioFileURL,
            segments: result.segments.map { .init(segment: $0) }
          )

          onComplete()

        } catch {
          Log.error("\(error.localizedDescription)")
        }
      }
    )
  }
}

private struct YouTubeImportContentView: View {

  @State private var urlString: String = ""
  @State private var url: URL? = nil
  @State private var isProcessing: Bool = false

  var onTranscribe: @MainActor (URL) async -> Void

  var body: some View {

    VStack {
      TextField("URL to YouTube", text: $urlString)
        .textContentType(.URL)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .disabled(isProcessing)

      Button("Transcribe") {

        guard let url else { return }

        Task { @MainActor in
          isProcessing = true
          defer {
            isProcessing = false
          }

          await onTranscribe(url)

        }

      }
      .buttonStyle(.borderedProminent)
      .disabled(isProcessing || url == nil)

      ProgressView()
        .opacity(isProcessing ? 1 : 0)
    }
    .padding()
    .onChange(of: urlString) { oldValue, newValue in
      let url = URL(string: newValue)
      self.url = url
    }

  }
}

#Preview {
  YouTubeImportContentView(onTranscribe: { _ in })
}
