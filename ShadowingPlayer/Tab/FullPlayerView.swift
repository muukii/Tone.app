import AppService
import SwiftData
import SwiftUI
import AVFoundation

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
    PlayerView<PlayerTextView>(
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
          case .debug(let debugAction):
            // Debug actions are handled in the view layer
            Log.debug("Debug action: \(debugAction)")
            
            switch debugAction {
            case .textKit:
              // TextKit actions are handled by the view
              break
            case .audioSession(let sessionAction):
              switchAudioSession(to: sessionAction)
            }
          }
        } catch {
          Log.error("\(error.localizedDescription)")
        }
      }
    )
  }
  
  private func switchAudioSession(to action: PlayerAction.DebugAction.AudioSessionAction) {
    Task {
      await player.performAudioSession {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
          switch action {
          case .switchToPlaybackCategory:
            try audioSession.setCategory(.playback, mode: .default)
            Log.debug("AudioSession switched to playback category")
          case .switchToRecordCategory:
            try audioSession.setCategory(.record, mode: .default)
            Log.debug("AudioSession switched to record category")
          case .switchToPlayAndRecordCategory:
            try audioSession.setCategory(.playAndRecord, mode: .default)
            Log.debug("AudioSession switched to playAndRecord category")
          case .switchToSoloAmbientCategory:
            try audioSession.setCategory(.soloAmbient, mode: .default)
            Log.debug("AudioSession switched to soloAmbient category")
          }
          
          try audioSession.setActive(true)
          Log.debug("AudioSession activated successfully")
        } catch {
          Log.error("Failed to switch AudioSession: \(error)")
        }
      }
    }
  }
}
