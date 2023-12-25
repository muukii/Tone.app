import SwiftUI
import SwiftUIIntrospect

struct RingSlider: View {

  final class Proxy: ObservableObject {
    @Published var value: Double = 0

    var contentOffsetObservation: NSKeyValueObservation?
    var isTrackingObservation: NSKeyValueObservation?

    init() {}

    deinit {
      contentOffsetObservation?.invalidate()
    }
  }

  @State private var observation: NSKeyValueObservation?
  @Binding var value: Double
  @State private var origin: Double?

  @StateObject var uiProxy: Proxy = .init()

  var body: some View {

    GeometryReader(content: { geometry in
      ScrollViewReader(content: { proxy in
        ScrollView(.horizontal) {
          HStack {
            ForEach(0..<2) { _ in
              HStack(spacing: 4) {
                ForEach(0..<6) { i in
                  Bar()
                  Spacer(minLength: 0)
                  RoundedRectangle(cornerRadius: 8)
                    .frame(width: 3, height: 10)
                    .foregroundColor(.red)
                  Spacer(minLength: 0)
                  ShortBar()
                  Spacer(minLength: 0)
                  ShortBar()
                  Spacer(minLength: 0)
                  ShortBar()
                  Spacer(minLength: 0)
                }
              }
              .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }
          }
        }
//        .sensoryFeedback(.selection, trigger: value)
        .scrollIndicators(.hidden)
        .introspect(.scrollView, on: .iOS(.v17)) { (view: UIScrollView) in

          uiProxy.contentOffsetObservation?.invalidate()

          uiProxy.isTrackingObservation = view.observe(\.isTracking) { view, _ in
            print("👽",view.isTracking)
          }

          uiProxy.contentOffsetObservation = view.observe(\.contentOffset) { view, value in

            print(view.panGestureRecognizer.state.rawValue)

            self.value += view.panGestureRecognizer.translation(in: view).x / view.bounds.width

            print("isTracking", view.isTracking, "isDragging", view.isDragging, "isDecelarating", view.isDecelerating)

            if view.isTracking, origin == nil {
              origin = view.contentOffset.x
            }

            if view.isTracking == false {
              origin = nil
            }

            print(origin)

            view.isDecelerating

            print(view.contentOffset.x)

            // for start
            if view.contentOffset.x < 0 {
              print("jump to end")
              view.contentOffset.x = view.contentSize.width - view.bounds.width
              return
            }

            // for end
            if view.contentOffset.x >= view.contentSize.width - view.bounds.width {
              print("back to start")
              view.contentOffset.x = 0
              return
            }
          }
        }
      })
      .mask {
        HStack(spacing: 0) {
          LinearGradient(
            stops: [
              .init(color: .black, location: 0),
              .init(color: .clear, location: 1),
            ],
            startPoint: .init(x: 1, y: 0),
            endPoint: .init(x: 0, y: 0)
          )
          Color.black.frame(width: 30)
          LinearGradient(
            stops: [
              .init(color: .black, location: 0),
              .init(color: .clear, location: 1),
            ],
            startPoint: .init(x: 0, y: 0),
            endPoint: .init(x: 1, y: 0)
          )
        }
      }
    })

  }

  // MARK: - nested types

  struct Bar: View {
    var body: some View {
      RoundedRectangle(cornerRadius: 8)
        .frame(width: 3, height: 30)
        .foregroundColor(.gray)
    }
  }

  struct ShortBar: View {
    var body: some View {
      RoundedRectangle(cornerRadius: 8)
        .frame(width: 3, height: 10)
        .foregroundColor(.gray)
    }
  }
}

#if DEBUG

fileprivate struct Demo: View {

  @State var value: Double = 0

  var body: some View {

    VStack {
      Text("\(String(format: "%.2f", value))")
      RingSlider(value: $value)
    }
  }

}

#Preview {
  Demo()
}
#endif
