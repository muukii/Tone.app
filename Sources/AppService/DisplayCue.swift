import SwiftSubtitles

public struct DisplayCue: Identifiable, Hashable {

  public func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
  }

  public var id: String { backed.id }

  public let backed: AbstractSegment

  public init(backed: Subtitles.Cue) {
    self.backed = .init(cue: backed)
  }

  public init(segment: AbstractSegment) {
    self.backed = segment
  }
}

import Foundation
import SwiftWhisper

public struct AbstractSegment: Equatable, Identifiable {

  public var id: String {
    "\(startTime),\(endTime)"
  }

  public let startTime: TimeInterval
  public let endTime: TimeInterval
  public let text: String

  init(cue: Subtitles.Cue) {
    self.startTime = cue.startTime.timeInSeconds
    self.endTime = cue.endTime.timeInSeconds
    self.text = cue.text
  }

  public init(segment: Segment) {
    self.startTime = Double(segment.startTime) * 0.001
    self.endTime = Double(segment.endTime) * 0.001
    self.text = segment.text
  }
}
