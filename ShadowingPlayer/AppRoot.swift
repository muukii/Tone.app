//
//  ShadowingPlayerApp.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import SwiftUI
import SwiftData
import AppService
import TipKit
import AVFoundation
import Atomics

@main
struct AppRoot: App {

  private let service = Service()

  init() {
    #if targetEnvironment(simulator)

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

    #endif

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
    }
    .modelContainer(service.modelContainer)

  }
}
