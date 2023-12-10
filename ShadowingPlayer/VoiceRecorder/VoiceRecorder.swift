// MARK: - Recorder
import AVFAudio
import SwiftUI

struct VoiceRecorderView: View {

  var body: some View {

    Button("Record") {
      
    }

  }
}

class Something {

  init() {

    let engine = AVAudioEngine()

    do {

      let documentDir = URL.documentsDirectory
      let filePath = documentDir.appending(path: "tmp_recording.caf")
      // オーディオフォーマット
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 44100,
        channels: 1,
        interleaved: true
      )!
      // オーディオファイル
      let audioFile = try AVAudioFile(forWriting: filePath, settings: format.settings)
      // inputNodeの出力バス(インデックス0)にタップをインストール
      // installTapOnBusの引数formatにnilを指定するとタップをインストールしたノードの出力バスのフォーマットを使用する
      // (この例だとフォーマットに inputNode.outputFormatForBus(0) を指定するのと同じ)
      // tapBlockはメインスレッドで実行されるとは限らないので注意
      let inputNode = engine.inputNode  // 端末にマイクがあると仮定する
      inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { (buffer, when) in
        do {
          // audioFileにバッファを書き込む
          try audioFile.write(from: buffer)
        } catch let error {
          print("audioFile.writeFromBuffer error:", error)
        }
      }

      do {
        // エンジンを開始
        try engine.start()
      } catch let error {
        print("engine.start() error:", error)
      }
    } catch let error {
      print("AVAudioFile error:", error)
    }
  }

}
