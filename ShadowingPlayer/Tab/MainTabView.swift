import SwiftUI
import AppService

struct MainTabView: View {

  let service: Service

  var body: some View {
    TabView {
      ListView(service: service)
        .tabItem {
          Label("List", systemImage: "list.bullet")
        }

      VoiceRecorderView(
        controller: RecorderAndPlayer()
      )
      .tabItem {
        Label("Recorder", systemImage: "mic")
      }
    }
  }
}
