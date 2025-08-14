import AppService
import SwiftData
import SwiftUI

struct FullPlayerView: View {
  @Query var pins: [PinEntity]
  
  let item: ItemEntity
  unowned let player: PlayerController
  let service: Service
  @Environment(\.dismiss) private var dismiss
  
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
      service: service,
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
            try await service.insertSeparator(
              for: item,
              beforeCueId: beforeCueId
            )
            try player.reloadCues(from: item)
          case .onDeleteSeparator(let cueId):
            try await service.deleteSeparator(for: item, cueId: cueId)
            try player.reloadCues(from: item)
          }
        } catch {
          Log.error("\(error.localizedDescription)")
        }
      }
    )
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "chevron.down")
            .font(.title3.weight(.semibold))
        }
      }
    }
  }
}