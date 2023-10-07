import SwiftUI

@propertyWrapper
public struct LazyState<Value>: DynamicProperty {

  @State var _value: Value?

  private let _initializer: () -> Value

  public init(wrappedValue value: @autoclosure @escaping () -> Value) {
    self._initializer = value
  }

  public init(initialValue value: @escaping () -> Value) {
    self._initializer = value
  }

  public func update() {

  }

  public var wrappedValue: Value {
    get {
      if _value == nil {
        _value = _initializer()
      }
      return _value!
    }
    nonmutating set {
      _value = newValue
    }
  }
}

#if DEBUG

@Observable
final class Controller {

  var name: String = ""
}

#Preview {

  struct MyView: View {

    @LazyState var controller: Controller = .init()

    var body: some View {
      Text(controller.name)
    }
  }

  return MyView()
}
#endif
