import AppService
import FunctionalViewComponent
import HexColorMacro
import StateGraph
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
  @ObjectEdge var mainViewModel = MainViewModel()

  init(
    rootDriver: RootDriver
  ) {
    self.rootDriver = rootDriver
  }

  var body: some View {
    TabView {
      AudioListView(
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
      AnkiView()
        .tabItem {
          Label("Vocabulary", systemImage: "textformat.abc")
        }
        .tint(#hexColor("FF5722", colorSpace: .displayP3))
        .modelContainer(for: [
          ExpressionTag.self,
          ExpressionItem.self,
        ])

      PlaygroundPanel()

      WebView(url: URL(string: "https://www.thesaurus.com/browse/apple")!)
        .tabItem {
          Label("Thesaurus", systemImage: "globe")
        }
        .tint(#hexColor("4CAF50", colorSpace: .displayP3))

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
        detailContent: {
          if let player = mainViewModel.currentController {
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
          if controller.isPlaying {
            controller.pause()
          } else {
            controller.play()
          }
        } label: {
          Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
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

  private func detailContent(
    player: PlayerController,
    namespace: Namespace.ID
  ) -> some View {

    let service = rootDriver.service

    if case .entity(let entity) = player.source {
      return PinEntitiesProvider(targetItem: entity) { pins in
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
