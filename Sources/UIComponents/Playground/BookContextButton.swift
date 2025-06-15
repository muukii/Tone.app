//
//  BookContextButton.swift
//  Tone
//
//  Created by Muukii on 2025/06/14.
//  Copyright © 2025 MuukLab. All rights reserved.
//


import SwiftUI

#Preview {
  BookContextButton()
}

struct BookContextButton: View, PreviewProvider {
  var body: some View {
    ContentView()
  }

  static var previews: some View {
    Self()
      .previewDisplayName(nil)
  }

  private struct ContentView: View {

    typealias Item = String

    @GestureState var hoverlingPoint: CGPoint?
    @State private var selectingItem: Item?

    var body: some View {

      ZStack {
        LensButton(keepsOpen: false, content: HoverView2())
      }
    }
  }

  /// this can't have states
  @MainActor
  protocol HoverContentProvider {

    associatedtype Body: View

    @MainActor
    func body(isOn: Bool, trackingPoint: CGPoint?) -> Body

  }

  private struct LensButton<ContentProvider: HoverContentProvider>: View {

    @State var isTracking: Bool = false
    @GestureState var hoverlingPoint: CGPoint?

    let content: ContentProvider
    private let keepsOpen: Bool

    init(
      keepsOpen: Bool,
      content: ContentProvider
    ) {
      self.content = content
      self.keepsOpen = keepsOpen
    }

    var body: some View {
      Capsule(style: .continuous)
        .opacity(isTracking ? 0.5 : 1)
        .frame(width: 200, height: 50)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($hoverlingPoint) { value, state, _ in
              state = value.location
            }
            .onChanged { value in
              isTracking = true
            }
            .onEnded { value in
              if keepsOpen == false {
                isTracking = false
              }
            }
        )
        .overlay {
          Color(white: 0, opacity: 0.2)
            .padding(-2000)
            .opacity(isTracking ? 1 : 0)
            .onTapGesture {
              isTracking = false
            }
        }
        .overlay {
          content.body(isOn: isTracking, trackingPoint: hoverlingPoint)
        }
        .animation(.bouncy, value: isTracking)
    }
  }

  private struct HoverView2: HoverContentProvider {

    func body(isOn: Bool, trackingPoint: CGPoint?) -> some View {

      HStack {

        if isOn {

          Selection<String>(hoverlingPoint: trackingPoint, item: "A")
            .transition(
              JumpTransition()
                .animation(
                  .spring(duration: 0.4, bounce: 0.6, blendDuration: 0)
                )
            )
          Selection<String>(hoverlingPoint: trackingPoint, item: "B")
            .transition(
              JumpTransition()
                .animation(
                  .spring(duration: 0.6, bounce: 0.5, blendDuration: 0)
                )
            )
          Selection<String>(hoverlingPoint: trackingPoint, item: "C")
            .transition(
              JumpTransition()
                .animation(
                  .spring(duration: 0.8, bounce: 0.2, blendDuration: 0)
                )
            )
        } else {
          EmptyView()
        }

      }
    }

  }

  private struct JumpTransition: Transition {

    func body(content: Content, phase: TransitionPhase) -> some View {

      content
        .scaleEffect(
          {
            switch phase {
            case .willAppear:
              return CGSize(width: 0.5, height: 0.5)
            case .identity:
              return CGSize(width: 1, height: 1)
            case .didDisappear:
              return CGSize(width: 0.5, height: 0.5)
            }
          }()
        )
        .opacity(
          {
            switch phase {
            case .willAppear:
              return 0
            case .identity:
              return 1
            case .didDisappear:
              return 0
            }
          }()
        )
        .blur(
          radius: {
            switch phase {
            case .willAppear:
              return 10
            case .identity:
              return 0
            case .didDisappear:
              return 10
            }
          }()
        )
        .offset(
          y: {
            switch phase {
            case .willAppear:
              return 0
            case .identity:
              return -50
            case .didDisappear:
              return -20
            }
          }())
    }

  }

  private struct HoverTransition: Transition {

    func body(content: Content, phase: TransitionPhase) -> some View {

      content
        .scaleEffect(
          {
            switch phase {
            case .willAppear:
              return CGSize(width: 0.5, height: 0.5)
            case .identity:
              return CGSize(width: 1, height: 1)
            case .didDisappear:
              return CGSize(width: 0.5, height: 0.5)
            }
          }()
        )
        .opacity(
          {
            switch phase {
            case .willAppear:
              return 0
            case .identity:
              return 1
            case .didDisappear:
              return 0
            }
          }()
        )
        .offset(
          y: {
            switch phase {
            case .willAppear:
              return 0
            case .identity:
              return -50
            case .didDisappear:
              return -20
            }
          }())
    }

  }

  private struct Selection<Item>: View {

    let hoverlingPoint: CGPoint?

    let item: Item

    var body: some View {
      TrackingView(
        hoverlingPoint: hoverlingPoint,
      ) { isOn in
        Circle()
          .scale(isOn ? 1.5 : 1)
          .offset(y: isOn ? -20 : 0)
          .fill(isOn ? Color.purple : Color.red)
          .animation(.bouncy, value: isOn)
          .sensoryFeedback(.impact(flexibility: .solid), trigger: isOn)
      }
      .frame(width: 50, height: 50)

    }
  }

  private struct TrackingView<Content: View>: View {

    let content: @MainActor (Bool) -> Content
    @State private var targetFrame: CGRect = .zero
    private let hoverlingPoint: CGPoint?

    init(
      hoverlingPoint: CGPoint?,
      @ViewBuilder content: @escaping @MainActor (Bool) -> Content
    ) {
      self.hoverlingPoint = hoverlingPoint
      self.content = content

    }

    var body: some View {
      
      Group {
        if let hoverlingPoint {
          let isOn = targetFrame.contains(hoverlingPoint)
          content(isOn)
        } else {
          content(false)
        }        
      }
        .onGeometryChange(
          for: CGRect.self,
          of: { proxy in
            proxy.frame(in: .global)
          },
          action: { value in                      
            targetFrame = value         
          }
        )

    }
  }

  enum TrackingViewPreference<Item>: PreferenceKey {

    static var defaultValue: Value {
      nil
    }

    typealias Value = Item?

    static func reduce(value: inout Value, nextValue: () -> Value) {
      let next = nextValue()
      if next != nil {
        value = next
      }
    }

  }

}
