import Foundation
import SwiftSubtitles

public nonisolated struct DisplayCue: Identifiable, Hashable, Sendable {

  public func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
  }

  public var id: String { backed.id }

  public var index: Int

  public let backed: AbstractSegment

  public init(backed: Subtitles.Cue, index: Int) {
    self.backed = .init(cue: backed)
    self.index = index
  }

  public init(segment: AbstractSegment, index: Int) {
    self.backed = segment
    self.index = index
  }

}

public nonisolated struct AbstractSegment: Equatable, Identifiable, Codable, Sendable {

  public var id: String {
    "\(startTime),\(endTime)"
  }

  public let startTime: TimeInterval
  public let endTime: TimeInterval
  public let text: String
  public let kind: Schemas.V3.SegmentKind

  public init(cue: Subtitles.Cue) {
    self.startTime = cue.startTime.timeInSeconds
    self.endTime = cue.endTime.timeInSeconds
    self.text = cue.text
    self.kind = .text
  }

  public init(startTime: TimeInterval, endTime: TimeInterval, text: String, kind: Schemas.V3.SegmentKind = .text) {
    self.startTime = startTime
    self.endTime = endTime
    self.text = text
    self.kind = kind
  }
}

public nonisolated struct StoredSubtitle: Codable, Sendable {

  public let items: [AbstractSegment]

  public init(items: [AbstractSegment]) {
    self.items = items
  }

  init(data: Data) throws {
    let decoder = JSONDecoder()
    self = try decoder.decode(Self.self, from: data)
  }

  @Sendable
  func encode() throws -> Data {

    let encoder = JSONEncoder()
    let data = try encoder.encode(self)
    return data

  }
}
