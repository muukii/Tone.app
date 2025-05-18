import SwiftUI

struct YouTubeDownloadView: View {

  var body: some View {

    Button("Download") {

      Task {

        do {
          try await YouTubeDownloader.run(
            url: .init(string: "https://www.youtube.com/watch?v=iMHFLKc5AFE&t=2s")!
          )
        } catch {
          Log.error("\(error.localizedDescription)")
        }

      }

    }

  }

}

#Preview {
  YouTubeDownloadView()
}
