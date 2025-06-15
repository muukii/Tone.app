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
  case onInsertSeparator(beforeCueId: String)
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
      
      HStack(spacing: 8) {
        Button {
          isDisplayingPinList = true
        } label: {
          Image(systemName: "list.bullet")
            .foregroundStyle(.primary)
        }       
        .frame(width: 44, height: 44)
        
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
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
        }
      }
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
        NavigationStack {
          PinListView(
            pins: pins,
            onSelect: { pin in
              isDisplayingPinList = false
              controller.setRepeating(from: pin)
            }
          )
        }
        .presentationDetents([.medium, .large])
      }
    )

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
