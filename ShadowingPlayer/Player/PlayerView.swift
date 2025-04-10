import AVFoundation
import AppService
import SwiftData
import SwiftUI
import SwiftUIRingSlider
import SwiftUISupport
import SteppedSlider
import Verge

@MainActor
protocol PlayerDisplay: View {

  init(
    controller: PlayerController,
    pins: [PinEntity],
    actionHandler: @escaping @MainActor (PlayerAction) async -> Void
  )
}

enum PlayerAction {
  case onPin(range: PlayingRange)
  case onTranscribeAgain
  case onRename(title: String)
}

struct PlayerView<Display: PlayerDisplay>: View {

  struct Term: Identifiable {
    var id: String { value }
    var value: String
  }

  @Reading<PlayerController> var state: PlayerController.State
  private let actionHandler: @MainActor (PlayerAction) async -> Void
  @State private var controllerForDetail: PlayerController?
  @State private var isDisplayingPinList: Bool = false
  @State private var isProcessing: Bool = false
  @State private var isShowingRenameDialog: Bool = false
  @State private var newTitle: String = ""

  private let pins: [PinEntity]
  private let namespace: Namespace.ID

  init(
    playerController: PlayerController,
    pins: [PinEntity],
    namespace: Namespace.ID,
    actionHandler: @escaping @MainActor (PlayerAction) async -> Void
  ) {
    self._state = .init(mode: .unowned, playerController)
    self.actionHandler = actionHandler
    self.pins = pins
    self.namespace = namespace
  }

  var body: some View {

    //
    ZStack {
      Display(
        controller: $state.driver,
        pins: pins,
        actionHandler: actionHandler
      )
    }
    .safeAreaInset(
      edge: .bottom,
      content: {
        PlayerControlPanel(
          controller: $state.driver,
          namespace: namespace,
          onTapPin: {

            guard let range = state.playingRange else {
              return
            }

            Task {
              await actionHandler(.onPin(range: range))
            }

          },
          onTapDetail: {
            controllerForDetail = $state.driver
          }
        )
      }
    )
    .navigationDestination(
      item: $controllerForDetail,
      destination: { controller in
        RepeatingView(controller: controller)
      }
    )
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .sheet(
      isPresented: $isDisplayingPinList,
      content: {
        PinListView(
          pins: pins,
          onSelect: { pin in
            isDisplayingPinList = false
            $state.driver.setRepeating(from: pin)
          }
        )
      }
    )
    .toolbar(content: {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          isDisplayingPinList = true
        } label: {
          Image(systemName: "list.bullet")
        }
        .contextMenu(menuItems: {
          Text("Display pinned items")
        })
      }

      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Menu("Transcribe again") {
            Text("It removes all of pinned items.")
            Button("Run") {
              Task {
                isProcessing = true
                defer { isProcessing = false }
                await actionHandler(.onTranscribeAgain)
              }
            }
          }
          
          Button("Rename") {
            newTitle = state.title
            isShowingRenameDialog = true
          }
        } label: {
          Image(systemName: "ellipsis")
        }
      }

    })
    .navigationBarTitleDisplayMode(.inline)
    .alert("Rename", isPresented: $isShowingRenameDialog) {
      TextField("Title", text: $newTitle)
      Button("Cancel", role: .cancel) { }
      Button("Rename") {
        Task {
          await actionHandler(.onRename(title: newTitle))
        }
      }
    } message: {
      Text("Enter new title")
    }
    .sheet(isPresented: $isProcessing) {
      VStack {
        Text("Processing")
        ProgressView()
      }
      .interactiveDismissDisabled(true)
    }

  }

}

private struct PinListView: View {

  let pins: [PinEntity]

  let onSelect: @MainActor (PinEntity) -> Void

  var body: some View {
    List {
      ForEach(pins) { pin in
        Button {
          onSelect(pin)
        } label: {
          // TODO: performance is so bad
          Text("\(Self.makeDescription(pin: pin))")
        }
      }
    }
  }

  private static func makeDescription(pin: PinEntity) -> String {

    guard let item = pin.item else {
      return ""
    }

    do {

      let whole = try item.segment().items

      let startCueID = pin.startCueRawIdentifier
      let endCueID = pin.endCueRawIdentifier

      let startCue = whole.first { $0.id == startCueID }!
      let endCue = whole.first { $0.id == endCueID }!

      let startTime = min(startCue.startTime, endCue.startTime)
      let endTime = max(startCue.endTime, endCue.endTime)

      let range = whole.filter {
        $0.startTime >= startTime && $0.endTime <= endTime
      }

      let text = range.map { $0.text }.joined(separator: " ")

      return text

    } catch {

      return ""
    }
  }
}

enum PlayerDisplayAction {
  case pin(DisplayCue)
  case move(to: DisplayCue)
  case setRepeat(range: PlayingRange)
}

struct PlayerControlPanel: View {
  
  @Reading<PlayerController> var state: PlayerController.State
  private let onTapPin: @MainActor () -> Void
  private let onTapDetail: @MainActor () -> Void

  let namespace: Namespace.ID

  init(
    controller: PlayerController,
    namespace: Namespace.ID,
    onTapPin: @escaping @MainActor () -> Void,
    onTapDetail: @escaping @MainActor () -> Void
  ) {
    self._state = .init(controller)
    self.namespace = namespace
    self.onTapPin = onTapPin
    self.onTapDetail = onTapDetail
  }

  private static func fractionLabel(fraction: CGFloat) -> String {
    if fraction < 1 {
      var text = String.init(format: "%0.2f", fraction)
      text.removeFirst()
      return text
    } else {
      return .init(format: "%.1f", fraction)
    }    
  }
  
  var body: some View {
    
    VStack {

      Spacer(minLength: 24).fixedSize()

      HStack(alignment: .center, spacing: 20) {

        // play or pause
        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }
          togglePlaying()
        } label: {
          Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(square: 30)
            .matchedGeometryEffect(id: MainTabView.ComponentKey.playButton, in: namespace)
            .foregroundColor(Color.primary)
            .contentTransition(.symbolEffect(.replace, options: .speed(2)))

        }
        .frame(square: 50)

        // repeat button
        Button {
          MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }

          if state.isRepeating {
            $state.driver.setRepeat(range: nil)
          } else {
            if let currentCue = state.currentCue {
              var range = $state.driver.makeRepeatingRange()
              range.select(cue: currentCue)
              $state.driver.setRepeat(range: range)
            }
          }
        } label: {
          ZStack {
            Image(systemName: "repeat")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 30)
              .foregroundStyle(Color.primary)
          }
          .padding(8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.accentColor.tertiary)
              .aspectRatio(1, contentMode: .fill)
              .opacity(state.isRepeating ? 1 : 0)
          )
        }
        .frame(square: 50)
        .tint(Color.accentColor)

        // pin
        Button {
          onTapPin()
        } label: {
          Image(systemName: "pin.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20)
            .foregroundColor(Color.primary)
        }
        .frame(square: 50)
        .buttonStyle(PlainButtonStyle())
        .disabled(state.isRepeating == false)

        // detail
        Button {
          onTapDetail()
        } label: {
          Image(systemName: "rectangle.portrait.and.arrow.forward")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 30)
            .foregroundColor(Color.primary)
        }
        .frame(square: 50)
        .buttonStyle(PlainButtonStyle())
        .disabled(state.isRepeating == false)

      }

      Spacer(minLength: 16).fixedSize()

      VStack {
        Button {
          $state.rate.wrappedValue = 1
        } label: {
          Text("\(String(format: "%.2f", state.rate))")
            .font(.title3.monospacedDigit().bold())
            .contentTransition(.numericText(value: 1))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .tint(Color.accentColor)
        
        SteppedSlider(
          value: $state.rate,
          range: 0.3...1,
          steps: 0.02,
          horizontalEdgeMask: .hidden,
          anchorView: {
            RoundedRectangle(cornerRadius: 1)
              .frame(width: 2, height: 20)
              .foregroundStyle(.tint)
          },
          segmentView: { _, _ in
            RoundedRectangle(cornerRadius: 1)
              .frame(width: 2, height: 20)
              .foregroundStyle(.tint.secondary)
          },
          segmentOverlayView: { index, _ in
            EmptyView()
          },
          onEditing: {}
        )
        .frame(height: 40)
        
      }

      Spacer(minLength: 10).fixedSize()
    }
//    .onChange(
//      of: speed,
//      initial: true,
//      { _, value in
//        $state.driver.setRate(value)
//      }
//    )
    .scrollIndicators(.hidden)
    .background(.quinary)
    .onKeyPress(.space) {
      togglePlaying()
      return .handled
    }
  }

  @MainActor
  private func togglePlaying() {
    if state.isPlaying {
      $state.driver.pause()
    } else {
      $state.driver.play()
    }
  }

}

struct DefinitionView: UIViewControllerRepresentable {
  let term: String

  func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
    return UIReferenceLibraryViewController(term: term)
  }

  func updateUIViewController(
    _ uiViewController: UIReferenceLibraryViewController,
    context: Context
  ) {
  }
}

#if DEBUG

#Preview {
  
  struct Host: View {
    
    @Namespace private var namespace
    
    @ReadingObject<PlayerController>({
      try! .init(item: .social)
    }) var state: PlayerController.State
    
    var body: some View {
      Group {
        NavigationStack {
          PlayerView<PlayerListFlowLayoutView>(
            playerController: $state.driver,
            pins: [],
            namespace: namespace,
              actionHandler: { action in
              }
          )
        }
        
      }
      .accentColor(Color.pink)
      .tint(Color.pink)
    }
  }
  
  return Host()
    
}

#endif
