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
      ListView(
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
    }
    .tint(.primary)    
    .overlay(
      Container(
        isCompact: $isCompact,
        namespace: namespace,
        marginToBottom: 54,
        compactContent: {
          if let player = state.currentController?.object {
            Text("Playing")
          } else {
            Text("Not playing")
          }
        },
        detailContent: {  
          if let player = state.currentController?.object?.object {
            detailContent(player: player)
          }
        },
        detailBackground: {
          Color.blue
        })
    )
  }
  
  private func detailContent(player: PlayerController) -> some View {
//    PinEntitiesProvider(targetItem: item) { pins in
    return PlayerView<PlayerListFlowLayoutView>(
        playerController: {
          return player
        },
        pins: [],
        actionHandler: { action in
//          do {
//            switch action {
//            case .onPin(let range):
//              try await service.makePinned(range: range, for: item)
//            case .onTranscribeAgain:
//              try await service.updateTranscribe(for: item)
//              path = .init()
//            case .onRename(let title):
//              try await service.renameItem(item: item, newTitle: title)
//            }
//          } catch {
//            Log.error("\(error.localizedDescription)")
//          }
        }
      )
//    }
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
