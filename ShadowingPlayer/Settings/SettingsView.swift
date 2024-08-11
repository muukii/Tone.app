import SwiftUI
import AppService

struct SettingsView: View {

  var body: some View {
    NavigationStack {
      Form {

        Section {
          Button("Start") {
            do {
              let state = MyActivityAttributes.ContentState()
              let r = try Activity.request(attributes: MyActivityAttributes(), contentState: state, pushType: nil)
//              self.currentActivity = r
            } catch {
              print(error)
            }
          }
        }

      }
      .navigationTitle("")
    }
  }
}

import ActivityKit
final class ActivityManager {
  
}

#Preview {
  SettingsView()
}
