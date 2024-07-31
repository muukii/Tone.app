import AppService
import HexColorMacro
import SwiftUI

struct MainTabView: View {

  let service: Service

  var body: some View {
    TabView {
      ListView(service: service)
        .tabItem {
          Label("List", systemImage: "list.bullet")
        }
        .tint(#hexColor("5A31FF", colorSpace: .displayP3))

//      VoiceRecorderView(
//        controller: RecorderAndPlayer()
//      )
//      .tabItem {
//        Label("Recorder", systemImage: "mic")
//      }
//      .tint(#hexColor("FB2B2B", colorSpace: .displayP3))

//      WhisperView()
//        .tabItem {
//          Label("Whisper", systemImage: "mic")
//        }
//        .tint(#hexColor("FB2B2B", colorSpace: .displayP3))
//
//      YouTubeDownloadView()
//        .tabItem {
//          Label("YouTube", systemImage: "mic")
//        }
//        .tint(#hexColor("FB2B2B", colorSpace: .displayP3))
    }
    .tint(.primary)
  }
}

#Preview {
  MainTabView(service: .init())
}
