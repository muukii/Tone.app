
import Foundation

public struct AbsolutePath: Hashable {

  /**
   /path/to/file
   */
  public let rawValue: String

  public init(url: URL) {
    self.rawValue = url.path(percentEncoded: false)
  }

  public var string: String {
    self.rawValue
  }

  public var url: URL {
    URL(filePath: self.rawValue)
  }

  public func relative(basedOn: AbsolutePath) -> RelativePath {

    var relative = rawValue
      .replacingOccurrences(of: basedOn.rawValue, with: "")

    if relative.hasPrefix("/") {
      relative.removeFirst()
    }

    return .init(relative)

  }
}

public struct RelativePath: Hashable {

  public let rawValue: String

  public init(_ value: consuming String) {
    var value = consume value
    if value.hasPrefix("/") {
      value.removeFirst()
    }
    self.rawValue = value
  }

  public func absolute(basedOn: AbsolutePath) -> AbsolutePath {
    .init(url: basedOn.url.appendingPathComponent(rawValue))
  }

}

