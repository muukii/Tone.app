import AppService
import SwiftData
import SwiftUI
import SwiftUIStack

struct PlatterRoot: View {

  let rootDriver: RootDriver
  @ObjectEdge var mainViewModel = MainViewModel()
  @State private var isExpanded = false
  @Namespace private var namespace
  
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
            .frame(height: isExpanded ? nil : 0)
            .opacity(isExpanded ? 1 : 0)
                    
          compactContent(player: player)          
          .opacity(isExpanded ? 0 : 1)
        }
        
      } else {
        Text("Not playing")
          .padding(12)
          .background(Capsule().opacity(0.2))
      }
    }
  }
  
  private func compactContent(player: PlayerController) -> some View {    
    HStack {
      Text(player.title)
        .onTapGesture {
          isExpanded = true
        }
        .padding(12)
        .background(Capsule().opacity(0.1))
      
      Button { 
        
      } label: { 
        Image(systemName: "xmark")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(square: 18)
          .padding(8)
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.circle)
    }
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

#Preview {
  Button { 
    
  } label: { 
    Image(systemName: "xmark")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(square: 18)
      .padding(8)
  }
  .buttonStyle(.bordered)
  .buttonBorderShape(.circle)
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
