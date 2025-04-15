import AppService
import HexColorMacro
import SwiftUI
import SwiftUIPersistentControl
import Verge
import FunctionalViewComponent
import WebKit

struct MainTabView: View {

  @Namespace var namespace
  
  enum ComponentKey: Hashable {
    case playButton
  }
  
  @State private var isCompact: Bool = true
  
  let service: Service
  
  @ReadingObject<MainViewModel> var state: MainViewModel.State
  
  init(service: Service) {
    self._state = .init({
      .init()
    })
    self.service = service
  }

  var body: some View {   
    TabView {
      AudioListView(
        service: service,
        onSelect: { item in 
          do {
            try $state.driver.setPlayerController(for: item)
            isCompact = false
          } catch {
            assertionFailure()
          }
        }
      )
        .tabItem {
          Label("List", systemImage: "list.bullet")
        }
        .tint(#hexColor("5A31FF", colorSpace: .displayP3))
        
      // Add the AnkiView tab
      AnkiView()
        .tabItem {
          Label("Vocabulary", systemImage: "textformat.abc")
        }
        .tint(#hexColor("FF5722", colorSpace: .displayP3))
        .modelContainer(for: [
          AnkiBook.self,
          AnkiItem.self,
        ])

      Form {
        Button("Open") {
          isCompact = false
        }
        Button("Close") {
          isCompact = true
        }
      }
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

      WebView(url: URL(string: "https://www.thesaurus.com/browse/apple")!)
        .tabItem {
          Label("Thesaurus", systemImage: "globe")
        }
        .tint(#hexColor("4CAF50", colorSpace: .displayP3))
    }
    .tint(.primary)    
    .overlay(
      Container(
        isCompact: state.currentController?.object?.object == nil ? .constant(true) : $isCompact,
        namespace: namespace,
        marginToBottom: 54,
        compactContent: {
          Group {
            if let player = state.currentController?.object?.object {              
              CompactPlayerBar(
                controller: player,
                namespace: namespace,
                onDiscard: {                  
                  $state.driver.discardPlayerController()                  
                })              
            } else {
              Text("Not playing")
            }
          }
          .frame(height: 60)
        },
        detailContent: {  
          if let player = state.currentController?.object?.object {
            detailContent(player: player, namespace: namespace)
          }
        },
        detailBackground: {
          Color(uiColor: .systemBackground)
        })
    )
  }
    
  private struct CompactPlayerBar: View {
    
    unowned let controller: PlayerController
    let namespace: Namespace.ID
    private let onDiscard: () -> Void
        
    init(
      controller: PlayerController,
      namespace: Namespace.ID,
      onDiscard: @escaping () -> Void
    ) {
      self.controller = controller
      self.namespace = namespace
      self.onDiscard = onDiscard
    }
    
    var body: some View {
      StoreReader(controller) { $state in
        HStack {
          Button {
            onDiscard()
          } label: {
            Image(systemName: "xmark")     
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(square: 30)
          }
          Button {
            MainActor.assumeIsolated {
              UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            if state.isPlaying {
              controller.pause()
            } else {
              controller.play()
            }
          } label: {
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(square: 30)
              .matchedGeometryEffect(id: ComponentKey.playButton, in: namespace)
              .foregroundColor(Color.primary)
              .contentTransition(.symbolEffect(.replace, options: .speed(2)))            
          }
          .frame(square: 50)
        }
      }
    }
    
  }
  
  private func detailContent(player: PlayerController, namespace: Namespace.ID) -> some View {
    if case .entity(let entity) = player.source {
      PinEntitiesProvider(targetItem: entity) { pins in
        PlayerView<PlayerListFlowLayoutView>(
          playerController: player,
          pins: pins,
          namespace: namespace,
          actionHandler: { action in          
            do {
              switch action {
              case .onPin(let range):
                try await service.makePinned(range: range, for: entity)
              case .onTranscribeAgain:
                try await service.updateTranscribe(for: entity)
              case .onRename(let title):
                try await service.renameItem(item: entity, newTitle: title)
              }
            } catch {
              Log.error("\(error.localizedDescription)")
            }
          }
        )
      }
    } else {
      fatalError()
    }
  }
}

struct WebView: UIViewRepresentable {
  let url: URL
  
  func makeUIView(context: Context) -> WKWebView {
    return WKWebView()
  }
  
  func updateUIView(_ webView: WKWebView, context: Context) {
    let request = URLRequest(url: url)
    webView.load(request)
  }
}

final class MainViewModel: StoreDriverType {
  
  @Tracking
  struct State {
    
    @PrimitiveTrackingProperty
    fileprivate(set) var currentController: ReferenceHolder<MainIsolated<PlayerController>>?
  }
  
  let store: Store<State, Never> = .init(initialState: .init())
  
  init() {
    
  }
    
  @MainActor
  func setPlayerController(for item: ItemEntity) throws {
              
    try commit {
      
      if let controller = $0.currentController?.object?.object {
        if controller.source == .entity(item) {
          return
        }
      }
      
      let newController = try PlayerController(item: item)
      
      $0.currentController?.dispose()
      $0.currentController = .init(.init(newController))
    }
    
  }
  
  @MainActor
  func discardPlayerController() {
    try? AudioSessionManager.shared.deactivate()
    commit { 
      $0.currentController?.object?.object.pause()
      $0.currentController?.dispose() 
      $0.currentController = nil
    }
  }
  
}

import os.lock

final class MainIsolated<T: AnyObject & Sendable>: Sendable {
  
  let object: T
  
  nonisolated init(_ object: T) {
    self.object = object
  }
  
  deinit {
    Task { @MainActor [object] in 
      _ = object
    }
  }
}

final class ReferenceHolder<T: AnyObject>: Sendable {
  
  var identifier: some Hashable {
    ObjectIdentifier(self)
  }
  
  nonisolated(unsafe)
  private(set) weak var object: T?
  
  nonisolated(unsafe)
  private let unmanaged: Unmanaged<T>
  
  nonisolated(unsafe)
  private var hasDisposed: Bool = false
  
  private let lock = OSAllocatedUnfairLock()
      
  init(_ object: T) {
    self.object = object
    self.unmanaged = Unmanaged.passUnretained(object).retain()
  }
  
  func dispose() {
    lock.lock()
    defer { lock.unlock() }
    guard !hasDisposed else { return }
    unmanaged.release()
    hasDisposed = true
  }
  
  deinit {
    lock.lock()
    defer { lock.unlock() }
    guard !hasDisposed else { return }
    unmanaged.release()
  }
  
}

#Preview {
  MainTabView(service: .init())
}
