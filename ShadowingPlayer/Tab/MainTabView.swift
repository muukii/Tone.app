import AppService
import HexColorMacro
import SwiftUI
import SwiftUIPersistentControl
import Verge

struct MainTabView: View {

  @Namespace var namespace
  
  @State private var isCompact: Bool = true
  
  let service: Service
  
  @Reading<MainViewModel> var state: MainViewModel.State
  
  init(service: Service) {
    self._state = .init({
      .init()
    })
    self.service = service
  }

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
    .overlay(
      Container(
        isCompact: $isCompact,
        namespace: namespace,
        marginToBottom: 54,
        compactContent: {
          HStack {
            Text("AA")
          }
          .frame(
            maxWidth: .infinity,
            minHeight: 50,
            maxHeight: 50
          )
        },
        detailContent: {         
        },
        detailBackground: {
          Color.blue
        })
    )
  }
}

final class MainViewModel: StoreDriverType {
  
  @Tracking
  struct State {
  }
  
  let store: Store<State, Never> = .init(initialState: .init())
  
  init() {
    
  }
  
}

#Preview {
  MainTabView(service: .init())
}
