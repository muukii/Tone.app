import AppService
import SwiftData
import SwiftUI
import SwiftUIStack

struct PlatterRoot: View {

  let rootDriver: RootDriver
  @ObjectEdge var mainViewModel = MainViewModel()
  @State private var isExpanded = false

  var body: some View {
    Platter(
      isExpanded: isExpanded,
      onTapMainContent: {
        isExpanded = false
      }
    ) {      
      NavigationStack {
        AudioListView(
          service: rootDriver.service,
          openAIService: rootDriver.openAIService,
          onSelect: { item in
            do {
              try mainViewModel.setPlayerController(for: item)
            } catch {
              assertionFailure()
            }
          }
        )
        .navigationDestination(for: TagEntity.self) { tag in
          AudioListInTagView(
            tag: tag,
            onSelect: { item in
              do {
                try mainViewModel.setPlayerController(for: item)
              } catch {
                assertionFailure()
              }
            }
          )
        }
      }
    } controlContent: {
      if let player = mainViewModel.currentController {
        ZStack {
          
          Group {
            detailContent(player: player)
              .frame(height: isExpanded ? nil : 0)
              .opacity(isExpanded ? 1 : 0)
          }
          
          Group {
            Text(player.title)
              .onTapGesture {
                isExpanded = true
              }
              .padding(12)
              .background(Capsule().opacity(0.2))
          }
          .opacity(isExpanded ? 0 : 1)
        }
        
      } else {
        Text("Not playing")
          .padding(12)
          .background(Capsule().opacity(0.2))
      }
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
