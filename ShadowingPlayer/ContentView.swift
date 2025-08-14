//
//  ContentView.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import SwiftUI
import AppService
import StateGraph

struct ContentView: View {

  let rootDriver: RootDriver
  @ObjectEdge private var mainViewModel = MainViewModel()

  var body: some View {
    TabViewRoot(rootDriver: rootDriver, mainViewModel: mainViewModel)
      .modelContainer(rootDriver.service.modelContainer)
      .onOpenURL { url in
        handleURL(url)
      }
  }
  
  private func handleURL(_ url: URL) {
    guard url.scheme == "tone" else { return }
    
    switch url.host {
    case "playPause":
      if let controller = mainViewModel.currentController {
        if controller.isPlaying {
          controller.pause()
        } else {
          controller.play()
        }
      }
    default:
      break
    }
  }
}
