### PlayerView: Insert Separator Before 実行後にビューが更新されない

- **概要**: `Insert Separator Before` 実行後、`PlayerView`/`PlayerListFlowLayoutView` にセパレータが表示されない。
- **優先度**: Medium
- **状態**: To Do

#### 再現手順
- プレイヤーを開く
- 任意のチャンクのコンテキストメニューから「Insert Separator Before」を実行
- ビューにセパレータが反映されない（表示が変わらない）

#### 原因
- `Service.insertSeparator` は `ItemEntity` のセグメントを書き換えるが、
  すでに表示中の `PlayerController` は初期化時に確定した `cues` を保持しており更新されない。
- `PlayerListFlowLayoutView` は `init` で `snapshot` を構築しており、`controller`/`cues` が更新されない限り再構築されない。

関連コード:
- `ShadowingPlayer/Shadowing/Player/PlayerListFlowLayoutView.swift`
- `ShadowingPlayer/Shadowing/Player/PlayerView.swift`
- `ShadowingPlayer/Shadowing/Library/PlayerController.swift`
- `Sources/AppService/Service.swift` (`insertSeparator` / `deleteSeparator`)
- `ShadowingPlayer/Tab/MainTabView.swift` (`EntityPlayerView` / `MainViewModel`)

#### 対応方針（短期修正）
1) `Service.insertSeparator` / `deleteSeparator` の完了後、同一 `ItemEntity` から新しい `PlayerController` を再構築して差し替える。
   - `MainViewModel` に以下を追加し、UI 側から呼び出す。
   - 英文コード例:
     ```swift
     @MainActor
     func refreshForUpdatedItem(_ item: ItemEntity) throws {
       let newController = try PlayerController(item: item)
       currentController = newController
     }
     ```
2) `EntityPlayerView` のアクションハンドラで `insertSeparator` / `deleteSeparator` 実行後に `refreshForUpdatedItem` を呼ぶ。
3) `detailContent`（`MainTabView`）から `EntityPlayerView` に `mainViewModel` を渡すようにする。

#### 将来の改善案（中期）
- `PlayerListFlowLayoutView` の `snapshot` を `body` 内で依存データから都度構築する（`init` 固定をやめる）。
- `PlayerController` にセグメント再読み込み API（例: `reloadCues(from: ItemEntity)`）を用意し、差し替え不要にする。
- `GraphStored`/`ObservableObject` 的な通知で `cues` 変更を伝搬できるようにする。

#### 影響範囲
- プレイヤー画面のセパレータ挿入/削除表示
- 同様の構成を用いる `PlatterRoot.PlayerWrapper` 側でも同対応が必要な可能性

#### 受け入れ条件
- 「Insert Separator Before」「Delete Separator」を実行後、即座に UI に追加/削除が反映される。
- 連続操作（複数回の挿入/削除）でも破綻しない。
- ビルドおよび基本的な再生/シーク機能に回 regress がない。

#### 作業チェックリスト
- [ ] `MainViewModel.refreshForUpdatedItem(_:)` を実装
- [ ] `EntityPlayerView` に `mainViewModel` を注入
- [ ] アクション後に `refreshForUpdatedItem(_:)` を呼び出す
- [ ] `PlatterRoot.PlayerWrapper` 側の同種ケースを確認・必要なら対応
- [ ] `tuist build` でビルド確認


