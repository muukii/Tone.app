import SwiftSubtitles

public struct DisplayCue: Identifiable, Hashable {

  public func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
  }

  public let id: String

  public let backed: Subtitles.Cue

  public init(backed: Subtitles.Cue) {
    self.backed = backed
    let s = backed.startTime
    self.id = "\(s.hour),\(s.minute),\(s.second),\(s.millisecond)"

  }
}
