import Foundation

public struct PlayingRange: Equatable {

  private var whole: [DisplayCue]

  public var startTime: TimeInterval {
    cues.first?.backed.startTime.timeInSeconds ?? whole.first?.backed.startTime.timeInSeconds ?? 0
  }
  public var endTime: TimeInterval {
    cues.last?.backed.endTime.timeInSeconds ?? whole.last?.backed.endTime.timeInSeconds ?? 0
  }

  public var startCue: DisplayCue {
    cues.first!
  }

  public var endCue: DisplayCue {
    cues.last!
  }

  private var cues: [DisplayCue] = []

  public init(
    whole: [DisplayCue]
  ) {
    self.whole = whole
  }

  public func contains(_ cue: DisplayCue) -> Bool {
    cue.backed.startTime.timeInSeconds >= startTime && cue.backed.endTime.timeInSeconds <= endTime
  }

  public mutating func select(startCueID: String, endCueID: String) {

    let startCue = whole.first { $0.id == startCueID }!
    let endCue = whole.first { $0.id == endCueID }!

    let startTime = min(startCue.backed.startTime.timeInSeconds, endCue.backed.startTime.timeInSeconds)
    let endTime = max(startCue.backed.endTime.timeInSeconds, endCue.backed.endTime.timeInSeconds)

    cues = whole.filter {
      $0.backed.startTime.timeInSeconds >= startTime && $0.backed.endTime.timeInSeconds <= endTime
    }

  }

  public mutating func select(cue: DisplayCue) {

    if cues.isEmpty {
      cues = [cue]
      return
    }

    if cues.contains(cue) {

      let count = cues.count
      let i = cues.firstIndex(of: cue)!

      if count / 2 < i {
        cues = Array(cues[...i])
      } else {
        cues = Array(cues[(i)...])
      }

    } else {

      let startTime = min(self.startTime, cue.backed.startTime.timeInSeconds)
      let endTime = max(self.endTime, cue.backed.endTime.timeInSeconds)

      cues = whole.filter {
        $0.backed.startTime.timeInSeconds >= startTime && $0.backed.endTime.timeInSeconds <= endTime
      }

    }

  }

  //    mutating func add(cue: DisplayCue) {
  //      guard cues.contains(cue) == false else { return }
  //      cues.append(cue)
  //      cues.sort { $0.backed.startTime < $1.backed.startTime }
  //    }
  //
  //    mutating func remove(cue: DisplayCue) {
  //      cues.removeAll { $0 == cue }
  //    }
}

