import AppService

enum PlayerAction {
  enum DebugAction: CustomStringConvertible {
    case textKit(TextKitAction)
    case audioSession(AudioSessionAction)
    
    enum TextKitAction: CustomStringConvertible {
      case forceTextKit1
      case forceTextKit2
      case useAutomaticTextKit
      
      var description: String {
        switch self {
        case .forceTextKit1:
          return "Force TextKit 1"
        case .forceTextKit2:
          return "Force TextKit 2"
        case .useAutomaticTextKit:
          return "Use Automatic TextKit Selection"
        }
      }
    }
    
    enum AudioSessionAction: CustomStringConvertible {
      case switchToPlaybackCategory
      case switchToRecordCategory
      case switchToPlayAndRecordCategory
      case switchToSoloAmbientCategory
      
      var description: String {
        switch self {
        case .switchToPlaybackCategory:
          return "Switch to Playback Category"
        case .switchToRecordCategory:
          return "Switch to Record Category"
        case .switchToPlayAndRecordCategory:
          return "Switch to PlayAndRecord Category"
        case .switchToSoloAmbientCategory:
          return "Switch to SoloAmbient Category"
        }
      }
    }
    
    var description: String {
      switch self {
      case .textKit(let action):
        return action.description
      case .audioSession(let action):
        return action.description
      }
    }
  }
  case onPin(range: PlayingRange)
  case onTranscribeAgain
  case onRename(title: String)
  case onInsertSeparator(beforeCueId: String)
  case onDeleteSeparator(cueId: String)
  case debug(DebugAction)
}
