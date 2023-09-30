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
    let databasePath = URL.documentsDirectory.appending(path: "database")
    do {
      let container = try ModelContainer(for: ItemEntity.self, configurations: .init(url: databasePath))
      self.modelContainer = container
    } catch {
      // TODO: delete database if schema mismatches or consider migration
      Log.error("\(error)")
      fatalError()
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(modelContainer)

  }
}
