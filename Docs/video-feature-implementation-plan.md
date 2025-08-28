# 動画トランスクリプション・再生機能実装計画

## 1. 概要

### 目的
Tone.appにおいて、動画ファイルをインポート・トランスクライブし、動画再生と字幕表示を同期させる機能を追加します。現在は音声のみを扱っていますが、動画を見ながらシャドーイング練習ができるようになることで、学習効果の向上が期待されます。

### 現在の実装状況
- 現在はYouTubeからのダウンロードやローカルファイルからのインポートで、音声ファイルのみを保存
- 動画ファイルが入力された場合は、音声を抽出した後に動画ファイル自体は削除されている
- WhisperKitを使った音声トランスクリプション機能が実装済み
- SwiftDataを使ったデータモデルがあり、音声ファイルパスと字幕データを保存

### 期待される成果
- 動画ファイルを保存し、再生できるようにする
- 動画再生と字幕表示を同期させる
- 既存のシャドーイング機能（速度調整、区間リピート、録音など）を動画再生時も利用可能にする

## 2. 技術設計

### データモデルの変更

#### ItemEntity (Schema V3)の拡張
```swift
public final class Item: Hashable {
  // 既存のプロパティ
  public var identifier: String?
  public var title: String = ""
  public var audioFilePath: String?
  // 追加するプロパティ
  public var videoFilePath: String?
  public var mediaType: MediaType = .audio
  
  // 追加するメソッド
  public var videoFileRelativePath: RelativePath? {
    videoFilePath.map { .init($0) }
  }
  
  public var videoFileAbsoluteURL: URL? {
    videoFileRelativePath?.absolute(
      basedOn: AbsolutePath(url: URL.documentsDirectory)
    ).url
  }
}

// 新しいenumを追加
public enum MediaType: Int, Codable {
  case audio = 0
  case video = 1
}
```

### ファイルストレージ構造

```
Documents/
  ├── audio/
  │   └── (音声ファイル)
  └── video/
      └── (動画ファイル)
```

### 動画プレイヤーアーキテクチャ

```
VideoPlayerController
  ├── AVPlayer (動画再生)
  ├── AudioTimeline (字幕同期)
  └── 再生制御 (再生/一時停止、速度調整など)

VideoPlayerView
  ├── AVPlayerView (動画表示)
  └── SubtitleView (字幕表示、既存と共通)
```

### UI/UX設計

1. **Platter UIの拡張**
   - 動画表示エリアをプレイヤー上部に追加
   - 字幕エリアは既存と同様に表示

2. **再生コントロール**
   - 既存の音声プレイヤーコントロールを継承
   - 動画表示サイズ切替オプションを追加

3. **インポート画面の更新**
   - ファイルピッカーで動画ファイル形式をサポート
   - YouTubeダウンロードで動画保持オプションを追加

## 3. 実装詳細

### 新規作成ファイル

1. **VideoPlayerController.swift**
```swift
final class VideoPlayerController {
  private let avPlayer: AVPlayer
  private var playerItem: AVPlayerItem?
  private var playerTimeObserver: Any?
  
  // AVPlayerとAudioTimelineの同期
  // 再生速度制御
  // リピート制御
}
```

2. **VideoPlayerView.swift**
```swift
struct VideoPlayerView: View {
  let controller: VideoPlayerController
  
  var body: some View {
    VStack {
      // 動画表示エリア
      // 字幕表示エリア（既存SubtitleViewを利用）
      // 再生コントロール
    }
  }
}
```

### 修正が必要な既存ファイル

1. **Schema.V3.ItemEntity.swift**
   - videoFilePath、mediaTypeプロパティの追加
   - 関連するメソッドの追加

2. **Service.swift**
   - importItem メソッドの更新
   - enqueueTranscribe メソッドの更新（動画ファイル保持）
   - 動画ファイル保存ディレクトリ作成処理

3. **YouTubeDownloader.swift**
   - 動画保持オプションの追加
   - 対応する動画フォーマットの選択

4. **PlayerView.swift**
   - メディアタイプに応じたビュー表示切替
   - VideoPlayerView/AudioPlayerViewの条件付き表示

5. **AudioAndSubtitleImportView.swift**
   - 動画ファイル形式のサポート

## 4. 実装ステップ

### フェーズ1: データモデルの拡張
- Schema V3 ItemEntityの拡張
- ファイルストレージ構造の変更
- 関連するユーティリティメソッドの追加

### フェーズ2: 動画保存機能
- 動画ファイルパス保存の実装
- YouTubeダウンロードの変更
- ファイルインポート処理の変更

### フェーズ3: 動画プレイヤーの実装
- VideoPlayerControllerの作成
- AVPlayerとAudioTimelineの同期
- 再生速度など既存機能の統合

### フェーズ4: UI統合
- VideoPlayerViewの作成
- Platter UIへの統合
- インタラクション処理の実装

### フェーズ5: テストとバグ修正
- 動画再生テスト
- 字幕同期テスト
- シャドーイング機能テスト

## 5. 技術的考慮事項

### パフォーマンス
- 大きな動画ファイルのメモリ管理
- 高解像度動画再生時のCPU/GPU使用量
- バックグラウンド処理の最適化

### ストレージ管理
- 動画ファイルの容量制限
- キャッシュ管理
- 不要ファイルの削除メカニズム

### バックグラウンド処理
- バックグラウンド時の動画処理（音声のみ継続）
- バックグラウンドタスク継続メカニズム

### エラーハンドリング
- 動画ファイル読み込みエラー
- フォーマット非対応エラー
- 同期エラー

## 6. 開発スケジュール

1. データモデル拡張: 1日
2. 動画保存機能: 2日
3. 動画プレイヤー実装: 3日
4. UI統合: 2日
5. テストとバグ修正: 2日

合計: 約10日間

## 7. 将来の拡張性

- 画面回転対応の改善
- Picture-in-Picture対応
- AirPlay対応
- ビデオフィルタ/エフェクト機能
- 字幕編集機能の強化