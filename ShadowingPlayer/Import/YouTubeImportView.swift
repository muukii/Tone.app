import SwiftUI

struct YouTubeImportView: View {

  @State private var urlString: String = ""
  @State private var url: URL? = nil
  @State private var isProcessing: Bool = false

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
            let audio = try await YouTubeDownloader.run(url: url)
            let modelRef = WhisperModelRef.enBase

            if await modelRef.isDownloaded() == false {
              try await WhisperModelDownloader.run(modelRef: modelRef)
            }

            let segments = try await WhisperTranscriber.run(url: audio, using: modelRef)

            print(segments)

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

#Preview {
  YouTubeImportView()
}
