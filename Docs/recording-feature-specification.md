# 録音機能仕様書

## 1. 概要

Toneアプリは英語学習者向けのシャドーイング練習アプリです。録音機能は、メイン音声を再生しながらユーザーの声を録音し、その録音を元の音声に重ねて再生することで、発音やイントネーションの練習を支援します。

### シャドーイングとは
- ネイティブスピーカーの音声を聞きながら、ほぼ同時に真似して発話する学習法
- 発音、リズム、イントネーションを改善する効果的な方法
- 録音機能により自分の発音を客観的に確認可能

## 2. アーキテクチャ

### コンポーネント構成

```
┌─────────────────────────────────────────────────────────┐
│                    PlayerView (UI層)                     │
│                           ↓                              │
│             PlayerControlPanel (UI制御層)                │
│                           ↓                              │
│             PlayerController (ビジネスロジック層)         │
│                           ↓                              │
│         AudioPlayerController (音声処理層)               │
│                    ├── AudioTimeline (同期管理)          │
│                    ├── AVAudioEngine × 2                │
│                    │   ├── 再生用エンジン                │
│                    │   └── 録音用エンジン                │
│                    └── AudioSessionManager              │
└─────────────────────────────────────────────────────────┘
```

### 主要クラスの責務

| クラス | 責務 |
|--------|------|
| **PlayerView** | UIの表示、ユーザーインタラクション処理 |
| **PlayerControlPanel** | 再生コントロールUI（録音ボタン含む） |
| **PlayerController** | 再生制御、状態管理 |
| **AudioPlayerController** | 音声エンジン管理、録音処理 |
| **AudioTimeline** | 複数トラックの同期管理 |
| **AudioSessionManager** | AVAudioSessionの設定管理 |

## 3. 技術仕様

### 音声処理仕様

| 項目 | 仕様 |
|------|------|
| **エンジン構成** | 再生用と録音用で別々のAVAudioEngine |
| **録音フォーマット** | CAF (Core Audio Format) |
| **サンプルレート** | 入力デバイス依存（通常48kHz） |
| **バッファサイズ** | 4096フレーム |
| **チャンネル数** | モノラルまたはステレオ（デバイス依存） |
| **録音ボリューム** | 再生時10倍増幅 |

### AudioSession設定

| モード | カテゴリ | オプション |
|--------|----------|------------|
| **通常再生** | `.playback` | `.allowBluetooth`, `.allowBluetoothA2DP` |
| **録音時** | `.playAndRecord` | `.allowBluetooth`, `.allowBluetoothA2DP` |
| **録音モード** | `.videoChat` | レイテンシと品質のバランス |

## 4. 実装詳細

### 4.1 録音開始フロー

```swift
1. ユーザーが録音ボタンを押下
   ↓
2. MicrophonePermissionManager で権限確認
   ↓
3. PlayerController.startRecording()
   ↓
4. AudioPlayerController.startRecording()
   - 現在の再生位置を取得 (offsetToMain)
   - AudioSessionを録音モードに切り替え
   - 録音専用エンジンを作成・起動
   - installTapで録音開始
```

### 4.2 録音処理

```swift
// 録音バッファの処理
recordingEngine.inputNode.installTap(
  onBus: 0,
  bufferSize: 4096,
  format: inputFormat
) { buffer, time in
  // バッファをファイルに書き込み
  try recording.writingFile.write(from: buffer)
}
```

### 4.3 録音停止と統合

```swift
1. 録音停止ボタン押下
   ↓
2. 録音エンジンのタップを削除
   ↓
3. 録音ファイルをクローズ
   ↓
4. AudioTimelineにトラックとして追加
   - offset: .timeInMain(recording.offsetToMain)
   - volume: 10倍増幅
   ↓
5. 同期再生可能に
```

## 5. 既知の問題

### 5.1 同期ズレ問題 ⚠️

**症状**: 録音した音声が徐々に元の音声とズレていく

**原因分析**:
```swift
// 問題のコード (AudioPlayerController.swift)
guard let currentTimeInMain = self.mainTrack!.currentTime() else {
  return
}
// ← ここで時間を取得

// ... 以下の処理で数十〜数百ms経過 ...
// - AudioSession設定変更
// - 録音エンジン作成
// - ノード接続
// - エンジン起動

setRecordingTap(with: nil)  // ← 実際の録音開始
```

**影響**: 
- 時間取得から録音開始まで50-200msの遅延
- この間もメイントラックは再生継続
- 結果として録音が遅れて開始される

### 5.2 再生速度変更時の問題

**症状**: 再生速度を変更すると録音位置がずれる

**原因**:
```swift
// AudioTimeline.swift
case .timeInMain(let offset):
  let a = timeInAudio - offset
  let rate = mainTrack.pitchControl.rate
  return a / Double(rate)  // レート計算の誤差
```

### 5.3 複数エンジンの非同期問題

**症状**: 再生と録音のタイミングが完全に同期しない

**原因**:
- 再生用と録音用で別々のAVAudioEngine使用
- エンジン間でクロック同期なし
- それぞれ独立したバッファリング

## 6. 改善提案

### 6.1 短期改善（同期精度向上）

#### 方法1: 事前準備方式
```swift
func startRecording() {
  // 1. 録音エンジンを事前に準備（タップ設定まで）
  prepareRecordingEngine()
  
  // 2. タイムスタンプ取得と録音開始を最小限の間隔で
  let timestamp = getCurrentTime()
  actuallyStartRecording(at: timestamp)
}
```

#### 方法2: AVAudioTimeベースの同期
```swift
// HostTimeではなくAVAudioTimeを使用
let nodeTime = mainTrack.player.lastRenderTime
let playerTime = mainTrack.player.playerTime(forNodeTime: nodeTime)
// より正確なタイムスタンプ
```

### 6.2 中期改善（アーキテクチャ改善）

#### 単一エンジン化
```swift
// 同じエンジンで録音と再生を管理
class UnifiedAudioEngine {
  let engine = AVAudioEngine()
  let playerNode = AVAudioPlayerNode()
  let mixerNode = AVAudioMixerNode()
  
  func setupForPlaybackAndRecording() {
    // 入力と出力を同じエンジンで処理
    engine.connect(engine.inputNode, to: mixerNode, format: inputFormat)
    engine.connect(playerNode, to: mixerNode, format: format)
    engine.connect(mixerNode, to: engine.mainMixerNode, format: format)
  }
}
```

#### リアルタイム補正
- 録音開始遅延を測定
- 自動的にオフセットを調整
- バッファレベルでの細かい同期

### 6.3 長期改善（機能拡張）

1. **録音管理機能**
   - 複数録音の管理UI
   - 録音ごとのミュート/削除
   - 録音のエクスポート

2. **視覚的フィードバック**
   - リアルタイム波形表示
   - 録音レベルメーター
   - 同期状態のインジケーター

3. **高度な機能**
   - ノイズ除去
   - 音声分析（発音評価）
   - 録音の自動位置調整

## 7. パフォーマンス指標

### 現在値と目標値

| 指標 | 現在値 | 目標値 | 備考 |
|------|--------|--------|------|
| **同期精度** | ±50-200ms | ±10ms | 人間が知覚できない範囲へ |
| **録音開始遅延** | 100-300ms | <50ms | ボタン押下から録音開始まで |
| **CPU使用率** | 15-20% | <10% | 録音中の平均値 |
| **メモリ使用量** | 1MB/分 | 維持 | 録音データのサイズ |
| **バッファアンダーラン** | 時々発生 | 0 | 音声の途切れ |

### 測定方法
- 同期精度: 録音と元音声の波形比較
- CPU/メモリ: Instrumentsでプロファイリング
- バッファ: AVAudioEngineのログ分析

## 8. 今後のロードマップ

### Phase 1: 基本的な同期改善（1-2週間）
- [ ] 録音開始タイミングの最適化
- [ ] AVAudioTimeベースの同期実装
- [ ] 遅延測定とログ出力

### Phase 2: アーキテクチャ改善（2-4週間）
- [ ] 単一エンジン化の検証
- [ ] プロトタイプ実装
- [ ] パフォーマンステスト

### Phase 3: UI/UX改善（2-3週間）
- [ ] 録音管理UI
- [ ] 視覚的フィードバック
- [ ] ユーザビリティテスト

### Phase 4: 高度な機能（4-6週間）
- [ ] エクスポート機能
- [ ] 音声分析
- [ ] クラウド同期

## 9. テスト計画

### ユニットテスト
- AudioTimeline の同期計算
- オフセット計算の精度
- バッファ処理

### 統合テスト
- 録音開始/停止フロー
- 複数トラックの同期再生
- AudioSession切り替え

### パフォーマンステスト
- 長時間録音（30分以上）
- 複数録音トラック（5つ以上）
- バックグラウンド動作

## 10. 参考資料

- [AVAudioEngine Documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Audio Session Programming Guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/)
- [Core Audio Overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)

---

最終更新: 2024年
作成者: Tone Development Team