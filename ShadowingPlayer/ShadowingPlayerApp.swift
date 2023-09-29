//
//  ShadowingPlayerApp.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import SwiftUI
import SwiftData

@main
struct ShadowingPlayerApp: App {

  private let modelContainer: ModelContainer

  init() {
    let container = try? ModelContainer(for: ItemEntity.self, configurations: .init())
    self.modelContainer = container!
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(modelContainer)

  }
}
