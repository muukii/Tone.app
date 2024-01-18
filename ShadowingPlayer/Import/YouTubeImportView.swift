import SwiftUI
import AppService
import YouTubeKit

struct YouTubeImportView: View {

  let service: Service
  @State private var urlString: String = ""
  @State private var url: URL? = nil
  @State private var isProcessing: Bool = false

  var onComplete: @MainActor () -> Void

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
          do {

            let title = try await YouTube(url: url).metadata?.title

            let audio = try await YouTubeDownloader.run(url: url)
            let modelRef = WhisperModelRef.enSmall

            if await modelRef.isDownloaded() == false {
              try await WhisperModelDownloader.run(modelRef: modelRef)
            }

            let segments = try await WhisperTranscriber.run(url: audio, using: modelRef)

            try await service.importItem(title: title ?? "(Not fetched)", audioFileURL: audio, segments: segments.map { .init(segment: $0) })

            onComplete()

          } catch {
            Log.error("\(error.localizedDescription)")
          }
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
