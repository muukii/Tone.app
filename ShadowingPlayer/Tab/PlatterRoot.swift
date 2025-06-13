import AppService
import SwiftData
import SwiftUI
import SwiftUIStack
import StateGraph
import UIComponents

struct PlatterRoot: View {

  let rootDriver: RootDriver
  let mainViewModel: MainViewModel
  @State private var isExpanded = false
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
    Platter(
      isExpanded: isExpanded,
      onTapMainContent: {
        isExpanded = false
      }
    ) {
      NavigationStack {
        AudioListView(
          namespace: namespace,
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
          .navigationTransition(.zoom(sourceID: tag, in: namespace))
        }        
      }
    } controlContent: {
      if let player = mainViewModel.currentController {
        ZStack {
          
          detailContent(player: player)
            .id(player)
            .frame(height: isExpanded ? nil : 0)
            .safeAreaInset(edge: .bottom, content: { 
              Button("Close") {
                isExpanded = false                
              }
            })
            .opacity(isExpanded ? 1 : 0)
                    
          compactContent(player: player)
            .opacity(isExpanded ? 0 : 1)
        }
        
      } else {
        EmptyPlayerView()
          .padding(.horizontal, 16)
      }
    }
  }
  
  private func compactContent(player: PlayerController) -> some View {    
    CompactPlayerView(
      title: player.title,
      isPlaying: player.isPlaying,
      onTap: {
        isExpanded = true
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
        isExpanded = false
      }
    )
    .padding(.horizontal, 16)
  }

  private func detailContent(
    player: PlayerController
  ) -> some View {

    let service = rootDriver.service

    if case .entity(let entity) = player.source {
      return PlayerWrapper(
        service: service,
        item: entity,
        player: player
      )
    } else {
      fatalError()
    }
    
  }
}

private struct CompactPlayerView: View {
  let title: String
  let isPlaying: Bool
  let onTap: () -> Void
  let onPlayPause: () -> Void
  let onClose: () -> Void
  
  @State private var isPressed = false  
  
  var body: some View {
    HStack(spacing: 16) {
      WaveformIndicator(isPlaying: isPlaying)
      VStack(alignment: .leading, spacing: 2) {
        MarqueeText(title)
          .font(.caption2)
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
      
      Button { 
        onClose()
      } label: { 
        Image(
          systemName: "xmark.circle.fill"
        )
        .font(.title3)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background {
      Capsule()
        .fill(.ultraThinMaterial)
        .overlay {
          Capsule()
            .strokeBorder(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }
    .animation(.snappy, body: { view in
      view
        .scaleEffect(isPressed ? 0.95 : 1.0)
    })
    ._onButtonGesture { pressing in
      isPressed = pressing
    } perform: {
      onTap()
    }    
  }
}

#Preview("Compact Player View - Playing") {
  CompactPlayerView(
    title: "Sample Audio Title",
    isPlaying: true,
    onTap: {
      print("Tapped")
    },
    onPlayPause: {
      print("Play/Pause")
    },
    onClose: {
      print("Close")
    }
  )
  .padding()
}

#Preview("Compact Player View - Paused") {
  CompactPlayerView(
    title: "Sample Audio Title",
    isPlaying: false,
    onTap: {
      print("Tapped")
    },
    onPlayPause: {
      print("Play/Pause")
    },
    onClose: {
      print("Close")
    }
  )
  .padding()
}


#Preview("Waveform Indicator - Playing") {
  WaveformIndicator(isPlaying: true)
    .padding()
}

#Preview("Waveform Indicator - Paused") {
  WaveformIndicator(isPlaying: false)
    .padding()
}

private struct EmptyPlayerView: View {
  @State private var isPressed = false
  
  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: "waveform")
        .font(.title3)
        .foregroundStyle(.tertiary)
        .frame(width: 24, height: 24)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("No Audio Playing")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.primary)
        
        Text("Select an audio to start")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      Image(systemName: "play.circle")
        .font(.title2)
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background {
      Capsule()
        .fill(.ultraThinMaterial)
        .overlay {
          Capsule()
            .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
        }
    }
    .opacity(0.8)
    .animation(.snappy, body: { view in
      view
        .scaleEffect(isPressed ? 0.98 : 1.0)
    })
    ._onButtonGesture { pressing in
      isPressed = pressing
    } perform: {
      // No action for empty state
    }
  }
}

#Preview("Empty Player View") {
  EmptyPlayerView()
    .padding()
}

private struct PlayerWrapper: View {
  @Query var pins: [PinEntity]

  let item: ItemEntity
  unowned let player: PlayerController
  let service: Service
  @Namespace private var namespace
  init(
    service: Service,
    item: ItemEntity,
    player: PlayerController
  ) {
    self.service = service
    self.item = item
    self.player = player

    let identifier = item.persistentModelID
    let predicate = #Predicate<PinEntity> { 
      $0.item?.persistentModelID == identifier
    }

    self._pins = Query.init(filter: predicate, sort: \.createdAt)
  }
  
  var body: some View {
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
          }
        } catch {
          Log.error("\(error.localizedDescription)")
        }
      }
    )
  }
}
