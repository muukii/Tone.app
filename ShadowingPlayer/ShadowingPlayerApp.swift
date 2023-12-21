//
//  ShadowingPlayerApp.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import SwiftUI
import SwiftData
import AppService

@main
struct ShadowingPlayerApp: App {

  private let service = Service()

  init() {
    #if targetEnvironment(simulator)

    let item = Item.social

    Task { [service] in
      try await service.importItem(
        title: "Example",
        audioFileURL: item.audioFileURL,
        subtitleFileURL: item.subtitleFileURL
      )
    }

    #endif
  }

  var body: some Scene {
    WindowGroup {
      ContentView(service: service)
        .tint(Color(.displayP3, red: 0.5607843137254902, green: 0.0, blue: 1.0, opacity: 1))
    }
    .modelContainer(service.modelContainer)

  }
}
