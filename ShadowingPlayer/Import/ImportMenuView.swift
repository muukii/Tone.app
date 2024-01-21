import AppService
import SwiftUI

struct ImportMenuView<AudioView: View, YouTubeView: View>: View {

  @State private var isImportingAudioAndSRT: Bool = false
  @State private var isImportingYouTube: Bool = false

  private let audioAndSubtitleImportView: () -> AudioView
  private let youTubeImportView: () -> YouTubeView

  init(
    audioAndSubtitleImportView: @escaping () -> AudioView,
    youTubeImportView: @escaping () -> YouTubeView
  ) {

    self.audioAndSubtitleImportView = audioAndSubtitleImportView
    self.youTubeImportView = youTubeImportView
  }

  var body: some View {

    VStack {
      Button("Audio and SRT") {
        isImportingAudioAndSRT = true
      }

      Button("YouTube") {
        isImportingYouTube = true
      }
    }
    .sheet(isPresented: $isImportingAudioAndSRT, content: {
      audioAndSubtitleImportView()
    })
    .sheet(isPresented: $isImportingYouTube, content: {
      youTubeImportView()
    })

  }
}

#Preview {
  ImportMenuView(
    audioAndSubtitleImportView: {
      Text("Audio")
  },
    youTubeImportView: {
      Text("YouTube")
    })
}
