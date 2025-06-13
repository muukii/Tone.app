import ActivityKit
import Intents
import SwiftUI
import WidgetKit

@main
struct Widgets: WidgetBundle {

  @WidgetBundleBuilder
  var body: some Widget {
    PlayerControlLiveActivity()  
  }
}
