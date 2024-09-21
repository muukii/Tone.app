import ActivityKit
import SwiftUI
import WidgetKit
import ActivityContent

struct ExpandedView: View {
  
  var body: some View {
    Text("Hoge")
      .activityBackgroundTint(.blue)
  }
}

struct MyWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration.init(for: MyActivityAttributes.self) { context in
      ExpandedView()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          ExpandedView()
        }
      } compactLeading: {
        Text(context.state.text)
      } compactTrailing: {
        Text(context.state.text)
      } minimal: {
        Text(context.state.text)
      }
    }
    
    
  }
}
