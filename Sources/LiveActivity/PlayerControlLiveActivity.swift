import ActivityContent
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit
import os.log

nonisolated let Log = Logger(subsystem: "liveActivity", category: "debug")

struct PlayerControlLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PlayerActivityAttributes.self) { context in
      // ロック画面に表示されるビュー
      LockScreenLiveActivityView(context: context)
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        // 展開時のビュー
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "music.note")
            .font(.title2)
            .foregroundColor(.white)
        }

        DynamicIslandExpandedRegion(.trailing) {
          // 再生状態の表示のみ（ボタンなし）
//          Image(systemName: context.state.isPlaying ? "waveform" : "pause.circle")
//            .font(.title2)
//            .foregroundColor(.white.opacity(0.7))
          Button(intent: Action()) {
            Text("Hit")
          }
        }

        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .center, spacing: 4) {
            Text(context.state.title)
              .font(.headline)
              .lineLimit(1)
              .foregroundColor(.white)

            if let artist = context.state.artist {
              Text(artist)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.white.opacity(0.7))
            }
          }

        }

      } compactLeading: {
        Image(systemName: "music.note")
          .font(.caption)
          .foregroundColor(.white)
      } compactTrailing: {
        // 再生状態の表示のみ
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.circle")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.7))

       
      } minimal: {
        Image(systemName: "music.note")
          .font(.caption2)
          .foregroundColor(.white)
      }
      .keylineTint(.white)
    }
  }
}

nonisolated struct Action: LiveActivityIntent {

  static var title: LocalizedStringResource {
    return "Hello"
  }

  func perform() async throws -> some IntentResult {

    Log.info("Hit")

    return .result()
  }

}

struct LockScreenLiveActivityView: View {
  let context: ActivityViewContext<PlayerActivityAttributes>

  var body: some View {
    HStack(spacing: 16) {
      // アイコン
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.white.opacity(0.1))
          .frame(width: 60, height: 60)

        Image(systemName: "music.note")
          .font(.title2)
          .foregroundColor(.white)
      }

      // 情報
      VStack(alignment: .leading, spacing: 4) {
        Text(context.state.title)
          .font(.headline)
          .lineLimit(1)
          .foregroundColor(.white)

        if let artist = context.state.artist {
          Text(artist)
            .font(.subheadline)
            .lineLimit(1)
            .foregroundColor(.white.opacity(0.7))
        }
      }

      Spacer(minLength: 0)

      // 再生状態の表示のみ
      ZStack {
        Circle()
          .fill(Color.white.opacity(0.1))
          .frame(width: 50, height: 50)

        Image(systemName: context.state.isPlaying ? "waveform" : "pause.circle")
          .font(.title3)
          .foregroundColor(.white.opacity(0.7))
      }
    }
    .padding(16)
  }
}

#Preview(
  "Lock Screen Live Activity",
  as: .content,
  using: PlayerActivityAttributes(itemId: "!")
) {
  PlayerControlLiveActivity()
} contentStates: {
  PlayerActivityAttributes.ContentState(
    title: "Learning Japanese",
    artist: "Shadowing Practice",
    isPlaying: true
  )
  PlayerActivityAttributes.ContentState(
    title: "English Conversation",
    artist: nil,
    isPlaying: false
  )
}
