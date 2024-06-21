import Foundation

public struct PlayingRange: Equatable, Sendable {

  private var whole: [DisplayCue]

  public var startTime: TimeInterval {
    cues.first?.backed.startTime ?? whole.first?.backed.startTime ?? 0
  }
  public var endTime: TimeInterval {
    cues.last?.backed.endTime ?? whole.last?.backed.endTime ?? 0
  }

  public var startCue: DisplayCue {
    cues.first!
  }

  public var endCue: DisplayCue {
    cues.last!
  }

  public private(set) var cues: [DisplayCue] = []

  public init(
    whole: [DisplayCue]
  ) {
    self.whole = whole
  }

  public func contains(_ cue: DisplayCue) -> Bool {
    cue.backed.startTime >= startTime && cue.backed.endTime <= endTime
  }

  public mutating func select(startCueID: String, endCueID: String) {

    let startCue = whole.first { $0.id == startCueID }!
    let endCue = whole.first { $0.id == endCueID }!

    let startTime = min(startCue.backed.startTime, endCue.backed.startTime)
    let endTime = max(startCue.backed.endTime, endCue.backed.endTime)

    cues = whole.filter {
      $0.backed.startTime >= startTime && $0.backed.endTime <= endTime
    }

  }

  public func after(_ cue: DisplayCue) -> DisplayCue? {
    whole.first { $0.backed.startTime > cue.backed.endTime }
  }

  public func before(_ cue: DisplayCue) -> DisplayCue? {
    whole.last { $0.backed.endTime < cue.backed.startTime }
  }

  public mutating func select(cue: DisplayCue) {

    if cues.isEmpty {
      cues = [cue]
      return
    }

    if cues.contains(cue) {

      if cues.last == cue {
        cues.removeLast()
      } else if cues.first == cue {
        cues.removeFirst()
      } else {
        
        let count = cues.count
        let i = cues.firstIndex(of: cue)!
        
        if count / 2 < i {
          cues = Array(cues[...i])
        } else {
          cues = Array(cues[(i)...])
        }
      }

    } else {

      let startTime = min(self.startTime, cue.backed.startTime)
      let endTime = max(self.endTime, cue.backed.endTime)

      cues = whole.filter {
        $0.backed.startTime >= startTime && $0.backed.endTime <= endTime
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

