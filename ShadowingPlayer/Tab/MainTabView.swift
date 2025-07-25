import AppService
import FunctionalViewComponent
import HexColorMacro
import StateGraph
import SwiftData
import SwiftUI
import SwiftUIPersistentControl
import WebKit
import os.lock

struct MainTabView: View {

  @AppStorage("openAIAPIKey") var openAIAPIKey: String = ""

  @Namespace var namespace

  enum ComponentKey: Hashable {
    case playButton
  }

  @State private var isCompact: Bool = true

  let rootDriver: RootDriver
  @ObjectEdge var ankiService = AnkiService()
  @ObjectEdge var mainViewModel = MainViewModel()

  init(
    rootDriver: RootDriver
  ) {
    self.rootDriver = rootDriver
  }

  var body: some View {
    TabView {
      AudioListView(
        namespace: namespace,
        service: rootDriver.service,
        openAIService: rootDriver.openAIService,
        onSelect: { item in
          do {
            try mainViewModel.setPlayerController(for: item)
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
      .modelContainer(rootDriver.service.modelContainer)

      // Add the AnkiView tab
//      AnkiView(ankiService: ankiService)
//        .tabItem {
//          Label("Vocabulary", systemImage: "textformat.abc")
//        }
//        .tint(#hexColor("FF5722", colorSpace: .displayP3))
//        .modelContainer(ankiService.modelContainer)

      TimelineWrapper()
//
//      WebView(url: URL(string: "https://www.thesaurus.com/browse/apple")!)
//        .tabItem {
//          Label("Thesaurus", systemImage: "globe")
//        }
//        .tint(#hexColor("4CAF50", colorSpace: .displayP3))

    }
    .onChange(
      of: openAIAPIKey, initial: true,
      { oldValue, newValue in
        rootDriver.setOpenAIAPIToken(newValue)
      }
    )
    .tint(.primary)
    .overlay(
      Container(
        isCompact: mainViewModel.currentController == nil
          ? .constant(true) : $isCompact,
        namespace: namespace,
        marginToBottom: 54,
        compactContent: {
          Group {
            if let player = mainViewModel.currentController {
              CompactPlayerBar(
                controller: player,
                namespace: namespace,
                onDiscard: {
                  mainViewModel.discardPlayerController()
                })
            } else {
              Text("Not playing")
            }
          }
          .frame(height: 60)
        },
        compactBackground: {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .shadow(
              color: .black.opacity(0.1),
              radius: 10,
              x: 0,
              y: 2
            )
        },
        detailContent: {
          if let player = mainViewModel.currentController {
            detailContent(player: player, namespace: namespace)
          }
        },
        detailBackground: {
          Rectangle()
            .fill(.background)
        })
    )
  }

  private struct CompactPlayerBar: View {

    unowned let controller: PlayerController
    private let namespace: Namespace.ID
    private let onDiscard: @MainActor () -> Void

    init(
      controller: PlayerController,
      namespace: Namespace.ID,
      onDiscard: @escaping @MainActor () -> Void
    ) {
      self.controller = controller
      self.namespace = namespace
      self.onDiscard = onDiscard
    }

    var body: some View {
      CompactPlayerBarContent(
        namespace: namespace,
        isPlaying: controller.isPlaying,
        onPlay: controller.play,
        onPause: controller.pause,
        onDiscard: onDiscard
      )
    }

  }

  struct CompactPlayerBarContent: View {

    let namespace: Namespace.ID
    private let onDiscard: @MainActor () -> Void
    private let isPlaying: Bool
    private let onPause: @MainActor () -> Void
    private let onPlay: @MainActor () -> Void

    init(
      namespace: Namespace.ID,
      isPlaying: Bool,
      onPlay: @escaping @MainActor () -> Void,
      onPause: @escaping @MainActor () -> Void,
      onDiscard: @escaping @MainActor () -> Void
    ) {
      self.namespace = namespace
      self.onDiscard = onDiscard
      self.isPlaying = isPlaying
      self.onPause = onPause
      self.onPlay = onPlay
    }

    var body: some View {

      HStack {

        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }
          if isPlaying {
            onPause()
          } else {
            onPlay()
          }
        } label: {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(square: 26)
            .matchedGeometryEffect(id: ComponentKey.playButton, in: namespace)
            .foregroundStyle(.primary)
            .contentTransition(.symbolEffect(.replace, options: .speed(2)))
        }
        //        .background(
        //          Circle()
        //            .blur(radius: 10)
        //        )
        .frame(square: 50)

        Text("Title")
          .font(.body)

        Spacer()

        Button {
          onDiscard()
        } label: {
          Image(systemName: "xmark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.primary)
            .frame(square: 10)
            .padding(2)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)

      }
      //      .background(.thinMaterial)
      .foregroundStyle(.primary)

    }

  }

  private func detailContent(
    player: PlayerController,
    namespace: Namespace.ID
  ) -> some View {

    let service = rootDriver.service

    if case .entity(let entity) = player.source {
      return EntityPlayerView(
        service: service,
        item: entity,
        player: player,
        namespace: namespace
      )
    } else {
      fatalError()
    }
  }
}

extension View {

}

#Preview("Bar") {
  MainTabView.CompactPlayerBarContent(
    namespace: Namespace().wrappedValue,
    isPlaying: false,
    onPlay: {},
    onPause: {},
    onDiscard: {}
  )
}

struct EntityPlayerView: View {

  @Query var pins: [PinEntity]

  let item: ItemEntity
  let namespace: Namespace.ID
  unowned let player: PlayerController
  let service: Service
  init(
    service: Service,
    item: ItemEntity,
    player: PlayerController,
    namespace: Namespace.ID
  ) {
    self.service = service
    self.item = item
    self.player = player
    self.namespace = namespace
    
    let identifier = item.persistentModelID

    let predicate = #Predicate<PinEntity> {
      $0.item?.persistentModelID == identifier
    }

    self._pins = Query.init(filter: predicate, sort: \.createdAt)
  }

  var body: some View {
    NavigationStack {
      PlayerView<PlayerListFlowLayoutView>(
        playerController: player,
        pins: pins,
        namespace: namespace,
        actionHandler: { action in
          do {
            switch action {
            case .onPin(let range):
              try await service.makePinned(range: range, for: item)
            case .onTranscribeAgain:
              try await service.updateTranscribe(for: item)
            case .onRename(let title):
              try await service.renameItem(item: item, newTitle: title)
            case .onInsertSeparator(let beforeCueId):
              try await service.insertSeparator(for: item, beforeCueId: beforeCueId)
            case .onDeleteSeparator(let cueId):
              try await service.deleteSeparator(for: item, cueId: cueId)
            }
          } catch {
            Log.error("\(error.localizedDescription)")
          }
        }
      )
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

final class MainViewModel {

  @GraphStored
  var currentController: PlayerController?

  init() {
    self.currentController = nil
  }

  @MainActor
  func setPlayerController(for item: ItemEntity) throws {

    if let controller = currentController {
      if controller.source == .entity(item) {
        return
      }
    }
    
    let newController = try PlayerController(item: item)

    currentController = newController
  }

  @MainActor
  func discardPlayerController() {
        
    try? AudioSessionManager.shared.deactivate()

    currentController?.pause()
    currentController = nil

  }

}
