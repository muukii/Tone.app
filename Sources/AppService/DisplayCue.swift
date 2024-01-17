import SwiftSubtitles

public struct DisplayCue: Identifiable, Hashable {

  public func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
  }

  public let id: String

  public let backed: AbstractSegment

  public init(backed: Subtitles.Cue) {
    self.backed = .init(cue: backed)
    let s = backed.startTime
    self.id = "\(s.hour),\(s.minute),\(s.second),\(s.millisecond)"
  }
}

import Foundation
import SwiftWhisper

public struct AbstractSegment: Equatable {

  public let startTime: TimeInterval
  public let endTime: TimeInterval
  public let text: String

  init(cue: Subtitles.Cue) {
    self.startTime = cue.startTime.timeInSeconds
    self.endTime = cue.endTime.timeInSeconds
    self.text = cue.text
  }

  init(segment: Segment) {
    self.startTime = Double(segment.startTime) * 0.001
    self.endTime = Double(segment.endTime) * 0.001
    self.text = segment.text
  }
}
