import ActivityKit
import SwiftUI
import WidgetKit

public struct MyActivityAttributes: ActivityAttributes {
  
  public struct ContentState: Codable, Hashable {
    public init() {
      
    }
  }
  
  public init() {
    
  }
  
}

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
        Text("🚌🚌")
      } compactTrailing: {
        Text("🚌🚌🚌")
      } minimal: {
        Text("🚌")
      }
    }
    
    
  }
}
