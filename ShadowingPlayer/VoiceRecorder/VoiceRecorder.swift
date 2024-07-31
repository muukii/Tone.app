// MARK: - Recorder
import AVFAudio
import AppService
import DSWaveformImageViews
import SwiftUI
import TipKit

struct SampleTip: Tip {
  var title: Text {
    Text("Record and playback")
  }

  var message: Text? {
    Text("Tap and hold to record")
  }

  var image: Image? {
    nil
  }

}

@MainActor
struct VoiceRecorderView: View {

  @ObjectEdge var controller: RecorderAndPlayer = .init()

  // TMP
  @State var isPlaying: Bool = false

  var body: some View {

    VStack {

      ScrollView(.vertical) {

        LazyVStack {

          ForEach(controller.recordedItems.reversed()) { item in
            Button {

            } label: {
              VStack {
                Text(item.duration, format: .time(pattern: .minuteSecond))
                  .font(.headline.bold().monospacedDigit())
                if item.duration > .zero {
                  WaveformView(
                    audioURL: item.filePath,
                    configuration: .init(
                      size: .zero,
                      backgroundColor: .clear,
                      style: .striped(.init(color: .red, width: 2, spacing: 2, lineCap: .round)),
                      damping: .init(percentage: 0.125, sides: .both),
                      verticalScalingFactor: 0.95,
                      shouldAntialias: true
                    )
                  )
                }
              }

            }
            .buttonStyle(.bordered)

          }
        }

        .backgroundStyle(.tint)
        .foregroundStyle(.tint)

      }
      .safeAreaPadding(.horizontal, 24)

      Spacer()

      TipView(SampleTip(), arrowEdge: .bottom) { a in

      }

      RecordingButtonButton { isPressing in
        if isPressing {
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))

            controller.stopAudio()
            isPlaying = false
            try controller.startRecording()
          }
        } else {
          controller.stopRecording()
          controller.playAudio()
          isPlaying = true
        }
      }

      // play or pause
      Button {
        MainActor.assumeIsolated {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        if isPlaying {
          controller.stopAudio()
          isPlaying = false
        } else {
          controller.playAudio()
          isPlaying = true
        }
      } label: {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(square: 30)
          .foregroundStyle(.secondary)
          .contentTransition(.symbolEffect(.replace, options: .speed(2)))

      }
      .frame(square: 50)

    }
    .onAppear {
//      controller.activate()
    }
    .onDisappear {
//      controller.deactivate()
    }

  }
}

private struct RecordingButtonButton: View {

  @State var isPressing: Bool = false

  var onPressing: (Bool) -> Void

  var body: some View {

    Circle()
      .frame(square: 80)
      .foregroundStyle(.primary)
      .animation(.snappy) { v in
        v.opacity(isPressing ? 0.2 : 1)
      }
      .padding(7)
      .overlay {
        Circle()
          .stroke(.secondary, lineWidth: 8)
      }
      .foregroundStyle(.tint)
      .sensoryFeedback(
        trigger: isPressing,
        { oldValue, newValue in
          if oldValue == false, newValue == true {
            return .impact(flexibility: .rigid, intensity: 1)
          }

          if oldValue == true, newValue == false {
            return .impact(flexibility: .solid, intensity: 0.8)
          }

          return nil
        }
      )
      ._onButtonGesture(
        pressing: { isPressing in
          self.isPressing = isPressing
          onPressing(isPressing)
        },
        perform: {

        }
      )

  }

}

#Preview {
  RecordingButtonButton(onPressing: { _ in })
}

@MainActor
@Observable
final class RecorderAndPlayer {

  struct Recorded: Equatable, Identifiable {

    var id: URL {
      filePath
    }

    let duration: Duration
    let filePath: URL

  }

  private(set) var recordedItems: [Recorded] = []

  private var playerController: AudioPlayerController?

  private let recorderController: VoiceRecorderController = .init()

  @ObservationIgnored
  private var currentRecordingFile: AVAudioFile?

  private var subscription: NSObjectProtocol?
  private var subscriptions: [NSObjectProtocol] = []

  init() {

    subscriptions.append(
      NotificationCenter.default.addObserver(
        forName: UIApplication.willResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }

        MainActor.assumeIsolated {
          self.recorderController.deactivate()
        }

      }
    )

    subscriptions.append(
      NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }

        MainActor.assumeIsolated {

          do {
            try self.recorderController.activate()
          } catch {
            Log.error("\(error.localizedDescription)")
          }
        }

      }
    )

  }

  deinit {
    MainActor.assumeIsolated {
      deactivate()
      for subscription in subscriptions {
        NotificationCenter.default.removeObserver(subscription)
      }
    }
  }

  func activate() {
    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(true)
      try instance.setCategory(
        .playAndRecord,
        mode: .spokenAudio,
        options: [.defaultToSpeaker]
      )

      try recorderController.activate()

    } catch {
      Log.error("\(error.localizedDescription)")
    }

    subscription = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { n in
      // TODO:
    }

  }

  func deactivate() {

    playerController?.pause()
    recorderController.deactivate()

    NotificationCenter.default.removeObserver(subscription as Any)

    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setActive(false)
    } catch {
      Log.error("\(error.localizedDescription)")
    }
  }

  func startRecording() throws {

    self.playerController?.pause()
    self.playerController = nil

    do {
      let recordingFile = try self.recorderController.startRecording()
      self.currentRecordingFile = recordingFile
    } catch {
      Log.error("\(error.localizedDescription)")
    }

  }

  func stopRecording() {

    guard let currentRecordingFile else {
      return
    }

    recorderController.stopRecording(file: currentRecordingFile)

    let file = currentRecordingFile

    let duration = Double(file.length) / file.fileFormat.sampleRate

    recordedItems.append(
      Recorded(duration: .seconds(duration), filePath: file.url)
    )
  }

  func playAudio() {

    guard let currentRecordingFile else {
      return
    }

    do {

      if playerController == nil {

        if let newInstance = try? AudioPlayerController.init(
          file: try .init(forReading: currentRecordingFile.url)
        ) {
          newInstance.repeating = .atEnd
          playerController = newInstance
          try playerController?.prepare()
        } else {
          // from some reason, can not play the audio file.
          return
        }
      }

      try playerController!.play()

    } catch {

      print(error)

    }
  }

  func stopAudio() {
    playerController?.pause()
  }

}

@MainActor
final class VoiceRecorderController {

  private let recordingEngine = AVAudioEngine()

  private var writingFiles: [AVAudioFile] = []

  private var hasInstalledTap: Bool = false

  init() {

  }

  @MainActor
  func activate() throws {

    if hasInstalledTap == false {
      print(recordingEngine.inputNode)
      
      Task { @MainActor in
        let box = await self.recordingEngine.inputNode
          .installTap(onBus: 0, bufferSize: 4096, format: nil)

        let (buffer, _) = box.value

        do {
          for file in self.writingFiles {
            try file.write(from: buffer)
          }
        } catch let error {
          print("audioFile.writeFromBuffer error:", error)
        }
      }        

      hasInstalledTap = true
    }

    try recordingEngine.start()
  }

  func deactivate() {
    if hasInstalledTap {
      recordingEngine.inputNode.removeTap(onBus: 0)
      hasInstalledTap = false
    }
    recordingEngine.stop()
  }

  func stopRecording(file: AVAudioFile) {
    writingFiles.removeAll(where: { $0 == file })
  }

  func startRecording() throws -> AVAudioFile {

    let inputFormat = recordingEngine.inputNode.outputFormat(forBus: 0)
    let destination = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")

    let newFile = try AVAudioFile(
      forWriting: destination,
      settings: inputFormat.settings
    )

    writingFiles.append(newFile)

    return newFile
  }

}

struct UnsafeSendableBox<V>: @unchecked Sendable {
  var value: V
}

extension AVAudioInputNode {
  @MainActor
  func installTap(
    onBus bus: AVAudioNodeBus,
    bufferSize: AVAudioFrameCount,
    format: AVAudioFormat?
  ) async -> UnsafeSendableBox<(AVAudioPCMBuffer, AVAudioTime)> {
    
    await withCheckedContinuation { continuation in
      self.installTap(onBus: bus, bufferSize: bufferSize, format: format) { @Sendable buffer, time in
        let box = UnsafeSendableBox.init(value: (buffer, time))
        continuation.resume(returning: box)
      }
    }
    
  }
}

#Preview {
  VoiceRecorderView()
    .tint(.yellow)
    .onAppear(perform: {
      try? Tips.resetDatastore()
      try? Tips.configure([
        .displayFrequency(.immediate)

      ])
    })
}
