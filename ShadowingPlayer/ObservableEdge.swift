import SwiftUI

@propertyWrapper
struct ObservableEdge<O: Observable> {

  @State private var box: Box<O> = .init()

  var wrappedValue: O {
    if let value = box.value {
      return value
    } else {
      box.value = factory()
      return box.value!
    }
  }

  private let factory: () -> O

  init(wrappedValue factory: @escaping @autoclosure () -> O) {
    self.factory = factory
  }

  private final class Box<Value> {
    var value: Value?
  }

}
