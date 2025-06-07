//
//  ContentView.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import SwiftUI
import AppService

struct ContentView: View {

  let rootDriver: RootDriver

  var body: some View {
//    MainTabView(rootDriver: rootDriver)
    PlatterRoot(rootDriver: rootDriver)
      .modelContainer(rootDriver.service.modelContainer)
  }
}
