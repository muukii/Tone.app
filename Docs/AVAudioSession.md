# AVAudioSession Documentation

## Overview

AVAudioSessionは、iOSアプリケーションのオーディオ動作を管理する重要なクラスです。このドキュメントでは、AVAudioSessionの使用時の注意点と、特にAVAudioEngineとの相互作用について説明します。

## 重要な問題: セッション変更によるAVAudioEngineの停止

### 問題の概要
AVAudioSessionの状態（カテゴリ、モード、アクティブ状態）を変更すると、実行中のAVAudioEngineが自動的に停止することがあります。

### 影響を受ける操作
- `setCategory(_:mode:options:)` の呼び出し
- `setActive(_:)` の呼び出し
- オーディオ出力デバイスの切り替え（ヘッドフォンの接続/切断など）

### 具体的な症状
1. AVAudioEngineが予期せず停止する
2. 音声の再生や録音が中断される
3. エンジンの再起動が必要になる

## 対策

### 1. 状態変更の最小化
```swift
// 現在の状態をチェックしてから変更
let currentCategory = AVAudioSession.sharedInstance().category
let currentMode = AVAudioSession.sharedInstance().mode

if currentCategory != desiredCategory || currentMode != desiredMode {
    // 必要な場合のみ変更
    try AVAudioSession.sharedInstance().setCategory(desiredCategory, mode: desiredMode)
}
```

### 2. AVAudioEngineの状態監視
```swift
// エンジンの状態を監視
if audioEngine.isRunning {
    // エンジンが実行中の場合の処理
}

// 通知による監視
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleEngineConfigurationChange),
    name: .AVAudioEngineConfigurationChange,
    object: audioEngine
)
```

### 3. 適切なタイミングでの設定
- アプリ起動時に一度だけ基本設定を行う
- 再生/録音の開始前に必要な設定を完了させる
- 実行中の変更は避ける

## Tone.appでの実装例

### AudioSessionManager
```swift
@MainActor
public final class AudioSessionManager {
    public static let shared = AudioSessionManager()
    
    private var instance: AVAudioSession {
        AVAudioSession.sharedInstance()
    }
    
    // 初期状態に設定する（再生のみ、AirPodsの音質を保つ）
    public func resetToDefaultState() {
        do {
            try instance.setCategory(
                .playback,  // 再生のみ（録音なし）
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            try instance.setActive(true)
        } catch {
            Log.error("Failed to reset audio session: \(error)")
        }
    }
    
    // アプリ起動時に一度だけ呼ぶ
    public func initialize() {
        resetToDefaultState()
    }
    
    // 録音最適化（カテゴリも変更）
    public func optimizeForRecording() throws {
        try instance.setCategory(
            .playAndRecord,  // 録音時のみ録音可能に
            mode: .videoChat,
            options: [.allowBluetooth, .allowBluetoothA2DP]
        )
    }
    
    // 再生最適化
    public func optimizeForPlayback() throws {
        try instance.setMode(.default)
    }
}
```

### AirPodsの音質問題への対応

**問題**: `.playAndRecord`カテゴリを使用すると、AirPodsなどのBluetoothヘッドフォンで音質が低下する（SCO Codecに切り替わるため）。

**解決策**: 
1. デフォルトは`.playback`カテゴリで再生のみ（高音質）
2. 録音が必要な時だけ`.playAndRecord`に切り替える
3. 録音終了後は`.playback`に戻す

## ベストプラクティス

1. **初期設定は一度だけ**: アプリ起動時に基本的なオーディオセッション設定を行い、頻繁な変更は避ける

2. **モード変更は最小限に**: 録音・再生の切り替え時のみモードを変更し、不要な変更は避ける

3. **エラーハンドリング**: セッション変更時のエラーを適切に処理する

4. **中断への対応**: 他のアプリや着信による中断に適切に対応する

5. **デバイス変更の監視**: ヘッドフォンの接続/切断などのルート変更を監視する

## 参考リンク
- [AVAudioEngine audio stops when switching the audio output device - Stack Overflow](https://stackoverflow.com/questions/66923293/avaudioengine-audio-stops-when-switching-the-audio-output-device)
- [Apple Developer Documentation - AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)

## パフォーマンス最適化

### Audio Input Tapの最適化
AVAudioEngineのinput nodeにタップを設定すると、継続的にオーディオバッファの処理が発生します。

**最適化戦略**:
1. **遅延設定**: 録音が必要になるまでタップの設定を遅延
2. **即時削除**: 録音終了後すぐにタップを削除
3. **リソース節約**: 不要な処理を削減し、バッテリー消費を抑制

```swift
// 録音開始時のみタップを設定
func startRecording() {
    // ... 録音準備 ...
    setTap()  // ここで初めてタップを設定
}

// 録音終了時にタップを削除
func stopRecording() {
    removeTap()  // 即座にタップを削除
    // ... 後処理 ...
}
```

## AVAudioEngine inputNodeの重要な仕様

### inputNodeを使用する前の確認事項
1. **フォーマットの有効性確認が必須**:
   ```swift
   let format = engine.inputNode.outputFormat(forBus: 0)
   guard format.sampleRate > 0 && format.channelCount > 0 else {
       // Input is not enabled
       return
   }
   ```

2. **動的な入出力切り替えには2つのエンジンを推奨**:
   - Appleの公式ドキュメントによると、出力専用と入出力モードを動的に切り替える場合は、2つの別々のAVAudioEngineインスタンスを使用することが推奨されている
   - 1つのエンジンで切り替えると、予期しない動作やクラッシュの原因となる可能性がある

### 現在の実装の課題
- 単一のAVAudioEngineで録音と再生を切り替えている
- AudioSession変更時のエンジン状態管理が複雑

## 今後の課題
- 出力専用エンジンと入出力用エンジンの2つに分離する実装の検討
- AVAudioEngineの状態を保持しながらセッション変更を行う方法の調査
- 中断からの復帰処理の実装
- デバイス切り替え時の自動復帰機能