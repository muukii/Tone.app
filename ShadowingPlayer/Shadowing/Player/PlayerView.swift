import AVFoundation
import AppService
import SteppedSlider
import SwiftData
import SwiftUI
import SwiftUIRingSlider
import SwiftUISupport

@MainActor
protocol PlayerDisplay: View {

  init(
    controller: PlayerController,
    pins: [PinEntity],
    actionHandler: @escaping @MainActor (PlayerAction) async -> Void
  )
}

nonisolated enum PlayerAction {
  case onPin(range: PlayingRange)
  case onTranscribeAgain
  case onRename(title: String)
}

struct PlayerView<Display: PlayerDisplay & Sendable>: View {

  nonisolated struct Term: Identifiable {
    var id: String { value }
    var value: String
  }

  unowned let controller: PlayerController
  private let actionHandler: @MainActor (PlayerAction) async -> Void
//  @State private var controllerForDetail: PlayerController?
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
    self.controller = playerController
    self.actionHandler = actionHandler
    self.pins = pins
    self.namespace = namespace
  }

  private var header: some View {
    HStack {
      Text(controller.title)
        .font(.headline)
        .bold()
        .foregroundStyle(.primary)
      Spacer()
//      Button {
//        controllerForDetail = nil
//      } label: {
//        Image(systemName: "xmark")
//          .foregroundStyle(.primary)
//      }
    }
    .padding(.horizontal, 16)
  }
  
  private var gradientMask: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .black.opacity(1), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(height: 20)
      
      Rectangle()
      
      Rectangle()
        .fill(
          LinearGradient(
            stops: [
              .init(color: .black.opacity(1), location: 0),
              .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(height: 20)
    }
  }

  var body: some View {
    VStack {
      header
      Display(
        controller: controller,
        pins: pins,
        actionHandler: actionHandler
      )
      .mask {
        gradientMask
      }
    }
    .safeAreaInset(
      edge: .bottom,
      spacing: 20,
      content: {

        PlayerControlPanel(
          controller: controller,
          namespace: namespace,
          onAction: { action in
            switch action {
            case .onTapPin:
              guard let range = controller.playingRange else {
                return
              }

              Task {
                await actionHandler(.onPin(range: range))
              }
            case .onTapDetail:
//              controllerForDetail = controller
              break
            case .onStartRecord:
              controller.startRecording()
            case .onStopRecording:
              controller.stopRecording()
            }
          }
        )
        .background(
          RoundedRectangle(cornerRadius: 32)
            .foregroundStyle(
              .quinary
            )
        )
        .padding(.horizontal, 8)
      }
    )
//    .navigationDestination(
//      item: $controllerForDetail,
//      destination: { controller in
//        RepeatingView(controller: controller)
//      }
//    )
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
            controller.setRepeating(from: pin)
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
            newTitle = controller.title
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
      Button("Cancel", role: .cancel) {}
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

      @ObjectEdge var playerController: PlayerController = try! .init(item: .social)

      var body: some View {
        Group {
          NavigationStack {
            PlayerView<PlayerListFlowLayoutView>(
              playerController: playerController,
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
