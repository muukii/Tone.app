import Foundation
import SwiftSubtitles

public struct DisplayCue: Identifiable, Hashable {

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

public struct AbstractSegment: Equatable, Identifiable, Codable, Sendable {

  public var id: String {
    "\(startTime),\(endTime)"
  }

  public let startTime: TimeInterval
  public let endTime: TimeInterval
  public let text: String

  public init(cue: Subtitles.Cue) {
    self.startTime = cue.startTime.timeInSeconds
    self.endTime = cue.endTime.timeInSeconds
    self.text = cue.text
  }

  public init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
    self.startTime = startTime
    self.endTime = endTime
    self.text = text
  }
}

public struct StoredSubtitle: Codable, Sendable {

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
