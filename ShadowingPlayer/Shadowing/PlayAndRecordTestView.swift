import AVFoundation
import SwiftUI

class PlayAndRecordViewModel: ObservableObject {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private var audioFile: AVAudioFile?
  private var outputFile: AVAudioFile?
  private var isRecording = false

  // 確認再生用
  private var confirmEngine: AVAudioEngine?
  private var confirmPlayer1: AVAudioPlayerNode?
  private var confirmPlayer2: AVAudioPlayerNode?

  func startPlayAndRecord() {
    
    MainActor.assumeIsolated {
      try? AudioSessionManager.shared.optimizeForRecording()
    }
    
    guard let inputURL = Bundle.main.url(forResource: "Social Media Has Ruined Photography", withExtension: "mp3") else {
      print("音声ファイルが見つかりません")
      return
    }
    do {
      audioFile = try AVAudioFile(forReading: inputURL)
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: audioFile?.processingFormat)

      try engine.start()
      player.scheduleFile(audioFile!, at: nil, completionHandler: nil)
      player.play()
      isRecording = true
    } catch {
      print("エラー: \(error)")
    }
  }

  func stop() {
    player.stop()
    engine.stop()
    engine.mainMixerNode.removeTap(onBus: 0)
    outputFile?.close()
    print(outputFile?.url)
    isRecording = false
  }

  func playBothFilesForConfirmation() {
    let recordedURL = FileManager.default.temporaryDirectory.appendingPathComponent("recorded.m4a")
    print(recordedURL)
    guard let originalURL = Bundle.main.url(forResource: "Social Media Has Ruined Photography", withExtension: "mp3") else {
      print("ファイルが見つかりません")
      return
    }
    do {
      let recordedFile = try AVAudioFile(forReading: recordedURL)
      let originalFile = try AVAudioFile(forReading: originalURL)

      let engine = AVAudioEngine()
      let recordedPlayerNode = AVAudioPlayerNode()
      let player2 = AVAudioPlayerNode()

      // 音量を分ける
      recordedPlayerNode.volume = 1.0 // 録音音声の音量
      player2.volume = 0.5            // 元音源の音量

      // パン（左右）を分ける
      recordedPlayerNode.pan = -1.0 // 左
      player2.pan = 1.0             // 右

      engine.attach(recordedPlayerNode)
      engine.attach(player2)

      let format = recordedFile.processingFormat
      engine.connect(recordedPlayerNode, to: engine.mainMixerNode, format: format)
      engine.connect(player2, to: engine.mainMixerNode, format: originalFile.processingFormat)

      try engine.start()
      recordedPlayerNode.scheduleFile(recordedFile, at: nil, completionHandler: nil)
      player2.scheduleFile(originalFile, at: nil, completionHandler: nil)
      recordedPlayerNode.play()
      player2.play()

      // 保持しておく（再生中に解放されないように）
      self.confirmEngine = engine
      self.confirmPlayer1 = recordedPlayerNode
      self.confirmPlayer2 = player2
    } catch {
      print("確認再生エラー: \(error)")
    }
  }
}

struct PlayAndRecordTestView: View {
  @StateObject private var viewModel = PlayAndRecordViewModel()
  @State private var isPlaying = false

  var body: some View {
    VStack {
      Button(isPlaying ? "Stop" : "Play & Record") {
        if isPlaying {
          viewModel.stop()
        } else {
          viewModel.startPlayAndRecord()
        }
        isPlaying.toggle()
      }
      Button("確認再生") {
        viewModel.playBothFilesForConfirmation()
      }
      .padding(.top, 16)
    }
    .padding()
  }
}
