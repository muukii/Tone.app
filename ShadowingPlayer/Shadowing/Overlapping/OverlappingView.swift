
import SwiftUI
import AppService

struct OverlappingView: View {

  let controller: PlayerController
  @State private var isRecording: Bool = false
  @State private var isShowingMicrophonePermissionAlert: Bool = false
  @Environment(\.dismiss) private var dismiss

  init(controller: PlayerController) {
    self.controller = controller
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
          // Header
          VStack(spacing: 12) {
            Text("Overlapping Mode")
              .font(.largeTitle)
              .fontWeight(.bold)
              .foregroundColor(.white)

            Text(controller.title)
              .font(.headline)
              .foregroundColor(.white.opacity(0.8))
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          .padding(.top, 40)

          Spacer()

          // Recording status
          if isRecording {
            HStack(spacing: 8) {
              Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                  Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.5)
                    .scaleEffect(2)
                    .animation(
                      Animation.easeInOut(duration: 1)
                        .repeatForever(autoreverses: true),
                      value: isRecording
                    )
                )

              Text("Recording...")
                .font(.headline)
                .foregroundColor(.white)
            }
          }

          // Recording button
          Button(action: toggleRecording) {
            ZStack {
              Circle()
                .fill(isRecording ? Color.red : Color.white)
                .frame(width: 80, height: 80)

              if isRecording {
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color.white)
                  .frame(width: 30, height: 30)
              } else {
                Circle()
                  .fill(Color.red)
                  .frame(width: 70, height: 70)
              }
            }
            .shadow(radius: 10)
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isRecording)
          }
          .buttonStyle(PlainButtonStyle())

          Spacer()

          // Instructions
          VStack(spacing: 8) {
            Text(isRecording ? "Tap to stop recording" : "Tap to start recording")
              .font(.callout)
              .foregroundColor(.white.opacity(0.7))

            Text("Record your voice while the audio plays")
              .font(.caption)
              .foregroundColor(.white.opacity(0.5))
          }
          .padding(.bottom, 40)
        }
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") {
            if isRecording {
              controller.stopRecording()
            }
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
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
      Text("Tone needs access to your microphone to record your voice during shadowing practice. Please enable microphone access in Settings.")
    }
  }

  private func toggleRecording() {
    if isRecording {
      // Stop recording
      controller.stopRecording()
      isRecording = false
    } else {
      // Start recording
      Task {
        let permissionManager = MicrophonePermissionManager()
        if await permissionManager.requestPermission() {
          controller.startRecording()
          isRecording = true
        } else {
          // Show alert if permission is denied
          if permissionManager.currentStatus == .denied {
            isShowingMicrophonePermissionAlert = true
          }
        }
      }
    }
  }
}

