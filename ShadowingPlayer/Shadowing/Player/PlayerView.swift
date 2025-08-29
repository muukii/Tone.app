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
    service: Service,
    actionHandler: @escaping @MainActor (PlayerAction) async -> Void
  )
}



struct PlayerView<Display: PlayerDisplay & Sendable>: View {

  struct Term: Identifiable {
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
  @State private var isShowingMicrophonePermissionAlert: Bool = false

  private let pins: [PinEntity]
  private let service: Service

  init(
    playerController: PlayerController,
    pins: [PinEntity],
    service: Service,
    actionHandler: @escaping @MainActor (PlayerAction) async -> Void
  ) {
    self.controller = playerController
    self.actionHandler = actionHandler
    self.pins = pins
    self.service = service
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
            .frame(width: 28, height: 28)
        }
        .buttonStyle(BorderedButtonStyle())

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
          
          #if DEBUG
          Divider()
          
          Menu("Debug - TextKit Version") {
            Button("Force TextKit 1") {
              Task {
                await actionHandler(.debug(.textKit(.forceTextKit1)))
              }
            }
            
            Button("Force TextKit 2") {
              Task {
                await actionHandler(.debug(.textKit(.forceTextKit2)))
              }
            }
            
            Button("Use Automatic Selection") {
              Task {
                await actionHandler(.debug(.textKit(.useAutomaticTextKit)))
              }
            }
          }
          
          Menu("Debug - AudioSession") {
            Button("Switch to Playback Category") {
              Task {
                await actionHandler(.debug(.audioSession(.switchToPlaybackCategory)))
              }
            }
            
            Button("Switch to Record Category") {
              Task {
                await actionHandler(.debug(.audioSession(.switchToRecordCategory)))
              }
            }
            
            Button("Switch to PlayAndRecord Category") {
              Task {
                await actionHandler(.debug(.audioSession(.switchToPlayAndRecordCategory)))
              }
            }
            
            Button("Switch to SoloAmbient Category") {
              Task {
                await actionHandler(.debug(.audioSession(.switchToSoloAmbientCategory)))
              }
            }
          }
          #endif

        } label: {
          Image(systemName: "ellipsis")
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
        }
        .buttonStyle(BorderedButtonStyle())

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
        service: service,
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
              Task.immediate {
                let permissionManager = MicrophonePermissionManager()
                if await permissionManager.requestPermission() {
                  controller.startRecording()
                } else {
                  // パーミッションが拒否されている場合はアラートを表示
                  if permissionManager.currentStatus == .denied {
                    isShowingMicrophonePermissionAlert = true
                  }
                }
              }
            case .onStopRecording:
              controller.stopRecording()
            }
          }
        )
        .frame(maxWidth: .infinity)
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
    .alert(
      "Microphone Access Required",
      isPresented: $isShowingMicrophonePermissionAlert
    ) {
      Button("Cancel", role: .cancel) {}
      Button("Open Settings") {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(settingsURL)
        }
      }
    } message: {
      Text(
        "Tone needs access to your microphone to record your voice during shadowing practice. Please enable microphone access in Settings."
      )
    }

  }

}

#if DEBUG

  #Preview {

    struct Host: View {

      @ObjectEdge var playerController: PlayerController = try! .init(
        item: .social
      )

      var body: some View {
        Group {
          NavigationStack {
            PlayerView<PlayerListFlowLayoutView>(
              playerController: playerController,
              pins: [],
              service: Service(),
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

#Preview("button") {

  @Previewable @State var isActive: Bool = false

  ZStack {
    HStack {
      ZStack {
        Color.white
        Button(isActive ? "Active" : "Inactive") {
          print("Hit")
          isActive.toggle()
        }
        .buttonStyle(_ButtonStyle(isActive: isActive))
      }
      ZStack {
        Color.red
        Button(isActive ? "Active" : "Inactive") {
          print("Hit")
          isActive.toggle()
        }
        .buttonStyle(_ButtonStyle(isActive: isActive))
      }
    }

    //  .buttonStyle(BorderedButtonStyle())
    //  .buttonStyle(PlainButtonStyle())
    //  .buttonStyle(DefaultButtonStyle())
    //  .buttonStyle(PlainButtonStyle())
    //  .buttonStyle(BorderlessButtonStyle())
    //    .buttonStyle(BorderedButtonStyle())
    //    .buttonBorderShape(.capsule)
    //    .backgroundStyle(.brown)
    //    .foregroundStyle(.red)
    //    .tint(.red)
    //  .buttonBorderShape(.capsule)
  }
}

struct _ButtonStyle: ButtonStyle {

  let isActive: Bool

  func makeBody(configuration: Configuration) -> some View {

    configuration.label
      .foregroundStyle(.primary)
      .blendMode(.overlay)
      //      .blendMode(isActive ? .destinationOut : .difference)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        isActive ? .regularMaterial : .ultraThinMaterial,
        in: Capsule()
      )
      .compositingGroup()
      .animation(.bouncy) {
        $0.opacity(configuration.isPressed ? 0.5 : 1)
      }

  }

}

#Preview {
  Rectangle()
    .fill(.blue)
    .overlay {
      Text("Hello")
        .blendMode(.overlay)
        .overlay(Text("Hello").opacity(1 - 0.5))
    }
}

