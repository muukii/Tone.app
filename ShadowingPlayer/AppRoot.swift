//
//  ShadowingPlayerApp.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import AVFoundation
import AppService
import SwiftData
import SwiftUI
import TipKit

@main
struct AppRoot: App {
  
  @State var rootDriver: RootDriver?

  init() {
    try? Tips.configure()

    //    do {
    //      let instance = AVAudioSession.sharedInstance()
    //      try instance.setCategory(
    //        .ambient,
    //        mode: .default,
    //        options: [.allowBluetooth, .allowAirPlay, .mixWithOthers]
    //      )
    //      try instance.setActive(true)
    //    } catch {
    //
    //    }
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if let rootDriver = rootDriver {        
          ContentView(rootDriver: rootDriver)
            .onAppear {
              UIApplication.shared.beginReceivingRemoteControlEvents()
              AudioSessionManager.shared.setInitialState()
#if targetEnvironment(simulator)
              Task {
                try await rootDriver.service.addExampleItems()
              }
#endif
            }
        } else {
          EmptyView()
        }
      }
      .task {
        self.rootDriver = .init()
      }
    }
    
  }
}
