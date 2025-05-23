import SwiftUI
import AppService

struct SettingsView: View {
  
  @StateObject var manager = ActivityManager.shared
  @AppStorage("openAIAPIKey") var openAIAPIKey: String = ""
      
  var body: some View {
    NavigationStack {
      Form {
        Section("OpenAI API") {
          SecureField("API Key", text: $openAIAPIKey)
            .textContentType(.password)
        }

        Section {
          Button("Start") {
            manager.startActivity()
          }
          Button("Stop") {
            manager.stopActivity()
          }
        }

      }
      .navigationTitle("Settings")
    }
  }
}

import ActivityKit
import ActivityContent

@MainActor
final class ActivityManager: ObservableObject {
  
  static let shared = ActivityManager()
  
  private var currentActivity: Activity<MyActivityAttributes>?
  
  private init() {
    
  }
  
  func startActivity() {
    do {
      
      let state = MyActivityAttributes.ContentState(text: "Hello!")
      
      let r = try Activity.request(
        attributes: MyActivityAttributes(),
        content: .init(state: state, staleDate: nil),
        pushType: nil
      )
      
      self.currentActivity = r
    } catch {
      print(error)
    }
  }
  
  func stopActivity(isolation: (any Actor)? = #isolation) {
    Task { @MainActor [currentActivity] in
      await currentActivity?.end(nil)
    }
  }
      
}

#Preview {
  SettingsView()
}
