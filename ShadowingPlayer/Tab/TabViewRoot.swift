import AppService
import StateGraph
import SwiftData
import SwiftUI
import UIComponents

struct TabViewRoot: View {
  
  let rootDriver: RootDriver
  let mainViewModel: MainViewModel
  
  @State private var selectedTab = 0
  @State private var showingFullPlayer = false
  @Namespace private var namespace
  
  init(rootDriver: RootDriver, mainViewModel: MainViewModel) {
    self.rootDriver = rootDriver
    self.mainViewModel = mainViewModel
  }
  
  private func setPlayer(for item: ItemEntity) {
    do {
      try mainViewModel.setPlayerController(for: item)
    } catch {
      assertionFailure()
    }
  }
  
  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Library", systemImage: "music.note.list", value: 0) {
        NavigationStack {
          AudioListView(
            service: rootDriver.service,
            openAIService: rootDriver.openAIService,
            onSelect: setPlayer
          )
          .navigationDestination(for: TagEntity.self) { tag in
            AudioListInTagView(
              service: rootDriver.service,
              tag: tag,
              onSelect: setPlayer
            )
          }
        }
      }    
    }
//    .onChange(of: mainViewModel.currentController) { _, newValue in
//      guard newValue != nil else { return }
//      showingFullPlayer = true 
//    }
    .fullScreenCover(isPresented: $showingFullPlayer) {
      if let player = mainViewModel.currentController {
        fullPlayerView(player: player)
      }
    }
    .tabViewBottomAccessory {
      if let player = mainViewModel.currentController {
        CompactPlayerAccessory(
          title: player.title,
          isPlaying: player.isPlaying,
          onTap: {
            showingFullPlayer = true
          },
          onPlayPause: {
            if player.isPlaying {
              player.pause()
            } else {
              player.play()
            }
          },
          onClose: {
            mainViewModel.discardPlayerController()
          }
        )
        .matchedTransitionSource(id: "player", in: namespace)
      }
    }
  }
  
  @ViewBuilder
  private func fullPlayerView(player: PlayerController) -> some View {
    let service = rootDriver.service
    
    if case .entity(let entity) = player.source {
      FullPlayerView(
        service: service,
        item: entity,
        player: player
      )
      .navigationTransition(.zoom(sourceID: "player", in: namespace))
    } else {
      EmptyView()
    }
  }
}

// Compact player view for bottomAccessory
struct CompactPlayerAccessory: View {
  let title: String
  let isPlaying: Bool
  let onTap: () -> Void
  let onPlayPause: () -> Void
  let onClose: () -> Void
  
  @State private var isPressed = false
  
  var body: some View {
    HStack(spacing: 16) {
      WaveformIndicator(isPlaying: isPlaying)
        .frame(width: 24, height: 24)
      
      VStack(alignment: .leading, spacing: 2) {
        MarqueeText(title)
          .font(.caption)
          .frame(height: 16)
        
        Text(isPlaying ? "Now Playing" : "Paused")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      // Play/Pause button
      Button {
        onPlayPause()
      } label: {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .font(.title3)
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.primary)
      }
      .buttonStyle(.plain)
      
      // Close button
      Button {
        onClose()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title3)
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .contentShape(Rectangle())
    .animation(
      .snappy,
      body: { view in
        view
          .scaleEffect(isPressed ? 0.95 : 1.0)
      }
    )
    ._onButtonGesture { pressing in
      isPressed = pressing
    } perform: {
      onTap()
    }
  }
}
