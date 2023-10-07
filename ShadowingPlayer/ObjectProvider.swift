import SwiftUI
/**
 https://developer.apple.com/forums/thread/739163
 */
public struct ObjectProvider<Object, Content: View>: View {

  @State private var object: Object?

  private let _objectInitializer: () -> Object
  private let _content: (Object) -> Content

  public init(object: @autoclosure @escaping () -> Object, @ViewBuilder content: @escaping (Object) -> Content) {
    self._objectInitializer = object
    self._content = content
  }

  public var body: some View {
    Group {
      if let object = object {
        _content(object)
      } else {
        Color.clear
          .onAppear {
            assert(object == nil, "it should not be running twice or more.")
            guard object == nil else { return }
            object = _objectInitializer()
          }
      }
    }

  }

}
