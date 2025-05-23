import Foundation

extension Duration {
  var timeInterval: TimeInterval {
    Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000.0
  }
  
  static func from(timeInterval: TimeInterval) -> Duration {
    let seconds = Int64(timeInterval)
    let attoseconds = Int64((timeInterval - Double(seconds)) * 1_000_000_000_000_000_000.0)
    return .init(secondsComponent: seconds, attosecondsComponent: attoseconds)
  }
}
