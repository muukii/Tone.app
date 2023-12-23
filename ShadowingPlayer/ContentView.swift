//
//  ContentView.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import SwiftUI
import AppService

struct ContentView: View {

  unowned let service: Service

  var body: some View {
    MainTabView(service: service)
  }
}
