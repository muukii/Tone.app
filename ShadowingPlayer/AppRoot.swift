//
//  ShadowingPlayerApp.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import AVFoundation
import AppService
import Atomics
import SwiftData
import SwiftUI
import TipKit

@main
struct AppRoot: App {

  private let service = Service()

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
      ContentView(service: service)
        .onAppear {
          UIApplication.shared.beginReceivingRemoteControlEvents()
          AudioSessionManager.shared.setInitialState()
          #if targetEnvironment(simulator)
          addExampleItems(using: service)
          #endif
        }
    }
    .modelContainer(service.modelContainer)

  }
}

#if targetEnvironment(simulator)
private func addExampleItems(using service: Service) {

  Task { [service] in
    let item = Item.social

    try await service.importItem(
      title: "Example",
      audioFileURL: item.audioFileURL,
      subtitleFileURL: item.subtitleFileURL
    )

    let a = Item.overwhelmed

    try await service.importItem(
      title: "overwhelmed",
      audioFileURL: a.audioFileURL,
      subtitleFileURL: a.subtitleFileURL
    )

  }

}
#endif
